import AppKit
import CryptoKit
import WebKit

/// "Sign in with All Hours": shows the real All Hours login page (login.spica.com) in a small window
/// and completes the same OAuth2 authorization-code + PKCE flow that pro.allhours.com uses.
/// Works with whatever login your company uses, and the app never sees your password.
@MainActor
final class WebSignIn: NSObject, WKNavigationDelegate, NSWindowDelegate {
    static let clientId = "pkce_client"
    static let redirectURI = "https://pro.allhours.com/auth-callback"
    static let scope = "openid profile api offline_access"

    struct Grant {
        let code: String
        let verifier: String
    }

    private static var current: WebSignIn?

    private let verifier = WebSignIn.randomToken(32)
    private let state = WebSignIn.randomToken(16)
    private var continuation: CheckedContinuation<Grant, Error>?
    private var window: NSWindow?
    private var spinner: NSProgressIndicator?

    /// Opens the login window and waits for the user to finish (or close it → `CancellationError`).
    static func run() async throws -> Grant {
        current?.finish(.failure(CancellationError()))
        let session = WebSignIn()
        current = session
        defer { if current === session { current = nil } }
        return try await withCheckedThrowingContinuation { continuation in
            session.continuation = continuation
            session.present()
        }
    }

    static func cancel() {
        current?.finish(.failure(CancellationError()))
    }

    /// Forgets the login.spica.com session so the next sign-in asks for credentials again.
    static func clearSession() async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        await store.removeData(ofTypes: types, for: records)
    }

    // MARK: - Window

    private func present() {
        let frame = NSRect(x: 0, y: 0, width: 460, height: 640)
        let webView = WKWebView(frame: frame, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimation(nil)

        let container = NSView(frame: frame)
        container.addSubview(webView)
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Sign in to All Hours"
        window.contentView = container
        window.contentMinSize = NSSize(width: 380, height: 480)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        self.window = window
        self.spinner = spinner
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        webView.load(URLRequest(url: authorizeURL))
    }

    private var authorizeURL: URL {
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        var components = URLComponents(string: "https://login.spica.com/connect/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url!
    }

    private func finish(_ result: Result<Grant, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
        window?.delegate = nil
        window?.close()
        window = nil
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, url.absoluteString.hasPrefix(Self.redirectURI) else {
            return .allow
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") {
            finish(.failure(AuthError.rejected(value("error_description") ?? "All Hours refused the sign-in (\(error)).")))
        } else if value("state") != state {
            finish(.failure(AuthError.rejected("The sign-in response didn't match. Please try again.")))
        } else if let code = value("code") {
            finish(.success(Grant(code: code, verifier: verifier)))
        }
        return .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner?.stopAnimation(nil)
        spinner?.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let code = (error as NSError).code
        // Cancelled loads (including our own redirect interception) aren't failures.
        guard code != NSURLErrorCancelled, code != 102 /* WebKitErrorFrameLoadInterruptedByPolicyChange */ else { return }
        finish(.failure(AuthError.unavailable("Couldn't load the All Hours sign-in page. Check your internet connection.")))
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        finish(.failure(CancellationError()))
    }

    // MARK: - PKCE helpers

    private static func randomToken(_ byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes).base64URLEncoded
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
