import Foundation

struct WireMessage: Decodable, Sendable {
    let id: String
    let body: String
    let sender: String
    let createdAt: Date
}

enum ChatClientError: Error {
    case notConfigured
    case http(Int)
    case decode(Error)
    case transport(Error)
}

actor ChatClient {
    static let shared = ChatClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func send(text: String, deviceId: String) async throws -> WireMessage {
        guard let baseURL = ChatKit.baseURL, let apiKey = ChatKit.apiKey else {
            throw ChatClientError.notConfigured
        }
        var req = URLRequest(url: baseURL.appendingPathComponent("api/v1/messages"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable { let deviceId: String; let text: String }
        req.httpBody = try encoder.encode(Body(deviceId: deviceId, text: text))

        return try await perform(req)
    }

    func fetch(since: Date?, deviceId: String) async throws -> [WireMessage] {
        guard let baseURL = ChatKit.baseURL, let apiKey = ChatKit.apiKey else {
            throw ChatClientError.notConfigured
        }
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/v1/messages"),
            resolvingAgainstBaseURL: false
        )!
        var query = [URLQueryItem(name: "deviceId", value: deviceId)]
        if let since {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            query.append(URLQueryItem(name: "since", value: formatter.string(from: since)))
        }
        components.queryItems = query

        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        return try await perform(req)
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw ChatClientError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ChatClientError.http(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ChatClientError.decode(error)
        }
    }
}
