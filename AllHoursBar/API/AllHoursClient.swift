import Foundation

enum APIError: LocalizedError {
    case offline
    case http(Int, String?)
    case unexpectedResponse(String)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            "Can't reach All Hours. Check your internet connection."
        case .http(let code, let message):
            if let message, !message.isEmpty { message }
            else if code == 403 { "All Hours says you don't have permission to do that." }
            else { "All Hours returned an error (HTTP \(code))." }
        case .unexpectedResponse(let path):
            "Unexpected response from All Hours (\(path))."
        case .message(let message):
            message
        }
    }
}

/// Thin authenticated wrapper around https://api4.allhours.com/api/v1.
@MainActor
final class AllHoursClient {
    private let base = URL(string: "https://api4.allhours.com/api/v1/")!
    private let tokens: TokenProvider

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { path in
            let key = path.last!.stringValue
            return AnyKey(stringValue: key.prefix(1).lowercased() + key.dropFirst())
        }
        return decoder
    }()

    /// Keeps nothing on disk: every response is personal and read once, so the shared session's
    /// cache only meant SQLite writes in ~/Library/Caches on every refresh.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    init(tokens: TokenProvider) {
        self.tokens = tokens
    }

    func get<T: Decodable>(_ type: T.Type, _ path: String, query: [String: String] = [:]) async throws -> T {
        let data = try await send("GET", path, query: query)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.unexpectedResponse(path)
        }
    }

    @discardableResult
    func post(_ path: String, json: [String: Any]) async throws -> Data {
        try await send("POST", path, json: json)
    }

    func delete(_ path: String) async throws {
        _ = try await send("DELETE", path)
    }

    private func send(_ method: String, _ path: String, query: [String: String] = [:], json: [String: Any]? = nil) async throws -> Data {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.percentEncodedQuery = query
                .sorted { $0.key < $1.key }
                .map { "\($0.key.formEncoded)=\($0.value.formEncoded)" }
                .joined(separator: "&")
        }

        var isRetry = false
        while true {
            let token = try await tokens.validToken(forceRefresh: isRetry)
            var request = URLRequest(url: components.url!, timeoutInterval: 20)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            // Same convention as JavaScript's Date.getTimezoneOffset(), which the web app sends.
            request.setValue(String(-TimeZone.current.secondsFromGMT() / 60), forHTTPHeaderField: "X-Timezone-Offset")
            if let json {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: json)
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await Self.session.data(for: request)
            } catch {
                throw APIError.offline
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 && !isRetry {
                isRetry = true
                continue
            }
            #if DEBUG
            Self.dump(data, method: method, path: path, status: status)
            #endif
            guard (200..<300).contains(status) else {
                throw APIError.http(status, Self.serverMessage(in: data))
            }
            return data
        }
    }

    #if DEBUG
    /// Debug builds: set ALLHOURS_DUMP_DIR to save every response body for inspection.
    private static func dump(_ data: Data, method: String, path: String, status: Int) {
        guard let dir = ProcessInfo.processInfo.environment["ALLHOURS_DUMP_DIR"] else { return }
        let name = "\(method)_\(path.replacingOccurrences(of: "/", with: "_"))_\(status).json"
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
    }
    #endif

    /// Pulls a human-readable message out of an error body (ASP.NET problem details, plain strings, …).
    private static func serverMessage(in data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            if let text = object as? String { return text }
            if let dict = object as? [String: Any] {
                if let errors = dict["errors"] as? [String: Any] {
                    let messages = errors.values.flatMap { ($0 as? [String]) ?? [] }
                    if !messages.isEmpty { return messages.joined(separator: " ") }
                }
                for key in ["Message", "message", "detail", "title", "error_description"] {
                    if let text = dict[key] as? String, !text.isEmpty { return text }
                }
            }
            return nil
        }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count < 200 && !text.hasPrefix("<") ? text : nil
    }
}
