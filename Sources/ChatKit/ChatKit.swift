import Foundation

public enum ChatKit {
    private(set) static var apiKey: String?
    private(set) static var baseURL: URL?

    public static func configure(apiKey: String, baseURL: URL) {
        Self.apiKey = apiKey
        Self.baseURL = baseURL
    }
}
