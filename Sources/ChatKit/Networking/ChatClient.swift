import Foundation
import UIKit

struct WireMessage: Decodable, Sendable {
    let id: String
    let body: String
    let imageUrl: String?
    let sender: String
    let createdAt: Date
}

enum ChatClientError: Error {
    case notConfigured
    case http(Int)
    case decode(Error)
    case transport(Error)
    case imageEncodingFailed
}

actor ChatClient {
    static let shared = ChatClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
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

    func send(text: String, image: UIImage?, deviceId: String) async throws -> WireMessage {
        guard let baseURL = ChatKit.baseURL, let apiKey = ChatKit.apiKey else {
            throw ChatClientError.notConfigured
        }

        let url = baseURL.appendingPathComponent("api/v1/messages")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let image {
            let (body, boundary) = try buildMultipart(text: text, image: image, deviceId: deviceId)
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        } else {
            struct Body: Encodable { let deviceId: String; let text: String }
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(Body(deviceId: deviceId, text: text))
        }

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

    // MARK: - Multipart

    private func buildMultipart(text: String, image: UIImage, deviceId: String) throws -> (Data, String) {
        guard let imageData = compressedJPEG(from: image) else {
            throw ChatClientError.imageEncodingFailed
        }

        let boundary = "ChatKit-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) {
            if let data = string.data(using: .utf8) {
                body.append(data)
            }
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"deviceId\"\r\n\r\n")
        append("\(deviceId)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"text\"\r\n\r\n")
        append("\(text)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        append("\r\n")

        append("--\(boundary)--\r\n")

        return (body, boundary)
    }

    private func compressedJPEG(from image: UIImage, maxBytes: Int = 8 * 1024 * 1024) -> Data? {
        var quality: CGFloat = 0.85
        while quality >= 0.2 {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.15
        }
        return image.jpegData(compressionQuality: 0.2)
    }

    // MARK: - Transport

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
