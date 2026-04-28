import Foundation

public enum ChatKit {
    private(set) static var apiKey: String?

    public static func configure(apiKey: String) {
        Self.apiKey = apiKey
    }
}
