import Foundation

/// What the user typed on the sign-in screen. Persisted as one Keychain item.
struct Credentials: Codable, Equatable {
    enum Method: String, Codable {
        /// The All Hours login page in a window (authorization code + PKCE, like pro.allhours.com).
        case web
        /// OAuth2 "resource owner" flow — email + password with a client ID/secret from All Hours.
        case password
        /// OAuth2 "client credentials" flow — a company API key; the user is identified by email.
        case apiKey
    }

    var method: Method
    var email: String
    var password: String
    var clientId: String
    var clientSecret: String
    var refreshToken: String?
}

enum AuthError: LocalizedError {
    /// The identity server refused the credentials; the user has to sign in again.
    case rejected(String)
    /// Network or server trouble; worth retrying later.
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .rejected(let message), .unavailable(let message): message
        }
    }
}

/// Talks to the All Hours identity server (login.spica.com) and hands out valid access tokens.
@MainActor
final class TokenProvider {
    private static let tokenURL = URL(string: "https://login.spica.com/connect/token")!
    private static let keychainAccount = "session"

    private(set) var credentials: Credentials?
    private var accessToken: String?
    private var expiresAt = Date.distantPast
    private var renewal: Task<String, Error>?

    /// Reads the saved session. Runs off the main thread because macOS may show a
    /// Keychain access prompt, and the menu bar icon should appear in the meantime.
    func loadSavedSession() async {
        let account = Self.keychainAccount
        let data = await Task.detached { Keychain.read(account) }.value
        credentials = data.flatMap { try? JSONDecoder().decode(Credentials.self, from: $0) }
    }

    func signIn(with candidate: Credentials) async throws {
        var creds = candidate
        guard let grant = initialGrant(for: creds) else { return }
        let token = try await requestToken(grant, creds: creds)
        creds.refreshToken = token.refreshToken
        credentials = creds
        store(token)
        persist()
    }

    /// Exchanges the code from `WebSignIn` for tokens.
    func completeWebSignIn(_ grant: WebSignIn.Grant) async throws {
        var creds = Credentials(method: .web, email: "", password: "", clientId: WebSignIn.clientId, clientSecret: "")
        let token = try await requestToken([
            "grant_type": "authorization_code",
            "code": grant.code,
            "code_verifier": grant.verifier,
            "redirect_uri": WebSignIn.redirectURI,
        ], creds: creds)
        creds.refreshToken = token.refreshToken
        credentials = creds
        store(token)
        persist()
    }

    /// Claims from the identity server (name, email/username); best effort.
    func userInfo() async -> [String: Any]? {
        guard let token = try? await validToken() else { return nil }
        var request = URLRequest(url: URL(string: "https://login.spica.com/connect/userinfo")!, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    func signOut() {
        renewal?.cancel()
        renewal = nil
        credentials = nil
        accessToken = nil
        expiresAt = .distantPast
        Keychain.delete(Self.keychainAccount)
    }

    func validToken(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let accessToken, expiresAt.timeIntervalSinceNow > 60 {
            return accessToken
        }
        if let renewal {
            return try await renewal.value
        }
        let task = Task { try await renew() }
        renewal = task
        defer { renewal = nil }
        return try await task.value
    }

    // MARK: - Private

    private func renew() async throws -> String {
        guard var creds = credentials else { throw AuthError.rejected("Please sign in.") }

        if let refreshToken = creds.refreshToken {
            do {
                let token = try await requestToken(["grant_type": "refresh_token", "refresh_token": refreshToken], creds: creds)
                creds.refreshToken = token.refreshToken ?? refreshToken
                credentials = creds
                store(token)
                persist()
                return token.accessToken
            } catch AuthError.rejected(let message) {
                // Refresh token expired or revoked: fall back to the stored password / API key below.
                if creds.method == .web { throw AuthError.rejected(message) }
            }
        }

        guard let grant = initialGrant(for: creds) else {
            throw AuthError.rejected("Your All Hours session has expired. Please sign in again.")
        }
        let token = try await requestToken(grant, creds: creds)
        creds.refreshToken = token.refreshToken
        credentials = creds
        store(token)
        persist()
        return token.accessToken
    }

    private func initialGrant(for creds: Credentials) -> [String: String]? {
        switch creds.method {
        case .web:
            nil
        case .password:
            ["grant_type": "password", "username": creds.email, "password": creds.password]
        case .apiKey:
            ["grant_type": "client_credentials"]
        }
    }

    private func requestToken(_ grant: [String: String], creds: Credentials) async throws -> TokenResponse {
        let grantType = grant["grant_type"] ?? ""
        // Not every client is allowed every scope, so retry with a narrower request on invalid_scope.
        let scopes: [String?] = switch grantType {
        case "password": ["api profile openid offline_access", "api"]
        case "client_credentials": ["api", nil]
        default: [nil]
        }

        var failure: TokenFailure?
        for scope in scopes {
            var form = grant
            form["client_id"] = creds.clientId
            if !creds.clientSecret.isEmpty { form["client_secret"] = creds.clientSecret }
            if let scope { form["scope"] = scope }
            do {
                return try await post(form)
            } catch let error as TokenFailure {
                failure = error
                if error.code != "invalid_scope" { break }
            }
        }
        throw authError(for: failure, grantType: grantType, method: creds.method)
    }

    private func post(_ form: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: Self.tokenURL, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data(form.map { "\($0.key.formEncoded)=\($0.value.formEncoded)" }.joined(separator: "&").utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.unavailable("Can't reach All Hours. Check your internet connection.")
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(status), let token = try? JSONDecoder().decode(TokenResponse.self, from: data) {
            return token
        }
        let body = try? JSONDecoder().decode(TokenErrorBody.self, from: data)
        throw TokenFailure(code: body?.error, status: status)
    }

    private func authError(for failure: TokenFailure?, grantType: String, method: Credentials.Method) -> AuthError {
        guard let failure else { return .unavailable("Sign-in failed.") }
        if failure.status >= 500 || failure.status == 0 {
            return .unavailable("The All Hours sign-in service is unavailable right now (HTTP \(failure.status)).")
        }
        switch failure.code {
        case "invalid_grant":
            let message = switch grantType {
            case "refresh_token": "Your All Hours session has expired. Please sign in again."
            case "authorization_code": "The sign-in took too long. Please try again."
            default: "Incorrect email or password."
            }
            return .rejected(message)
        case "invalid_client":
            return .rejected("The client ID or client secret was not accepted.")
        case "unauthorized_client", "unsupported_grant_type":
            return .rejected(method == .password
                ? "This client ID can't sign in with email and password. Check the client ID and secret, or try the API key option."
                : "This client ID can't be used as an API key. Check it in All Hours → Settings → Advanced.")
        case "invalid_scope":
            return .rejected("This client doesn't have access to the All Hours API.")
        default:
            return .rejected("Sign-in failed (\(failure.code ?? "HTTP \(failure.status)")).")
        }
    }

    private func store(_ token: TokenResponse) {
        accessToken = token.accessToken
        expiresAt = Date().addingTimeInterval(token.expiresIn ?? 3600)
    }

    private func persist() {
        guard let credentials, let data = try? JSONEncoder().encode(credentials) else { return }
        Keychain.write(data, to: Self.keychainAccount)
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Double?
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

private struct TokenErrorBody: Decodable {
    let error: String?
}

private struct TokenFailure: Error {
    let code: String?
    let status: Int
}

extension String {
    /// application/x-www-form-urlencoded / query-safe encoding (unreserved ASCII only).
    var formEncoded: String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return addingPercentEncoding(withAllowedCharacters: unreserved) ?? self
    }
}
