import SwiftUI

struct SignInView: View {
    @Environment(AttendanceStore.self) private var store

    @State private var showOtherOptions = false
    @State private var method: Credentials.Method = .password
    @State private var email = ""
    @State private var password = ""
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var didPrefill = false
    @FocusState private var focused: Field?

    private enum Field { case email, password, clientId, clientSecret }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                Text("All Hours Bar")
                    .font(.system(size: 17, weight: .semibold))
                Text("Clock in and out from your menu bar.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            if let error = store.signInError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.clockOut)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showOtherOptions {
                otherOptions
            } else {
                webSignIn
            }

            HStack {
                Button(showOtherOptions ? "Back to All Hours sign-in" : "Other ways to sign in") {
                    withAnimation(.snappy(duration: 0.2)) { showOtherOptions.toggle() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.accentColor)
                .disabled(store.isSigningIn)
                Spacer()
                IconButton(symbol: "power", help: "Quit All Hours Bar") { NSApp.terminate(nil) }
            }
        }
        .padding(20)
        .onAppear(perform: prefill)
    }

    // MARK: - Primary: the All Hours login page

    private var webSignIn: some View {
        VStack(spacing: 10) {
            if store.isSigningIn {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Finish signing in in the All Hours window…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 38)
                Button("Cancel") { store.cancelSignIn() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    Task { await store.signInWithAllHours() }
                } label: {
                    Label("Sign in with All Hours", systemImage: "person.badge.key.fill")
                }
                .buttonStyle(ProminentButtonStyle(tint: .brandBottom))

                Text("Opens the All Hours login page. Use the same account as on pro.allhours.com. The app stays signed in until you sign out.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Fallback: password grant or API key

    private var otherOptions: some View {
        VStack(spacing: 12) {
            Picker("Sign in with", selection: $method) {
                Text("Email & Password").tag(Credentials.Method.password)
                Text("API Key").tag(Credentials.Method.apiKey)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(spacing: 10) {
                field("Work email") {
                    TextField("name@company.com", text: $email)
                        .textContentType(.username)
                        .focused($focused, equals: .email)
                }
                if method == .password {
                    field("Password") {
                        SecureField("All Hours password", text: $password)
                            .textContentType(.password)
                            .focused($focused, equals: .password)
                    }
                }
                HStack(spacing: 8) {
                    field("Client ID") {
                        TextField("Client ID", text: $clientId)
                            .focused($focused, equals: .clientId)
                    }
                    field(method == .password ? "Client secret (if any)" : "Client secret") {
                        SecureField("Secret", text: $clientSecret)
                            .focused($focused, equals: .clientSecret)
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            .onSubmit(submit)

            Button(action: submit) {
                HStack(spacing: 8) {
                    if store.isSigningIn { ProgressView().controlSize(.small).tint(.white) }
                    Text(store.isSigningIn ? "Signing In…" : "Sign In")
                }
            }
            .buttonStyle(ProminentButtonStyle(tint: .brandBottom))
            .disabled(!canSubmit || store.isSigningIn)

            Text(hint)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hint: String {
        switch method {
        case .apiKey:
            "An admin creates the key in All Hours → Settings → Advanced → API. Your email is used to find your profile."
        default:
            "For clients issued by All Hours. Your password is kept in your Mac's Keychain."
        }
    }

    private var canSubmit: Bool {
        let hasEmail = email.contains("@")
        let hasClient = !clientId.trimmingCharacters(in: .whitespaces).isEmpty
        switch method {
        case .apiKey: return hasEmail && hasClient && !clientSecret.isEmpty
        default: return hasEmail && !password.isEmpty && hasClient
        }
    }

    private func submit() {
        guard canSubmit, !store.isSigningIn else { return }
        let creds = Credentials(
            method: method,
            email: email.trimmingCharacters(in: .whitespaces),
            password: method == .password ? password : "",
            clientId: clientId.trimmingCharacters(in: .whitespaces),
            clientSecret: clientSecret.trimmingCharacters(in: .whitespaces)
        )
        Task { await store.signIn(creds) }
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        let defaults = UserDefaults.standard
        if let creds = store.prefill, creds.method != .web {
            showOtherOptions = true
            method = creds.method
            email = creds.email
            clientId = creds.clientId
            clientSecret = creds.clientSecret
        } else {
            if let raw = defaults.string(forKey: Prefs.lastMethod), let saved = Credentials.Method(rawValue: raw), saved != .web {
                method = saved
            }
            email = defaults.string(forKey: Prefs.lastEmail) ?? ""
            clientId = defaults.string(forKey: Prefs.lastClientId) ?? clientId
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
