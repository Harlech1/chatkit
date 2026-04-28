import Foundation
import os

public enum ChatKit {
    private struct Config: Sendable {
        var apiKey: String?
        var baseURL: URL?
    }

    private static let storage = OSAllocatedUnfairLock(initialState: Config())

    static var apiKey: String? { storage.withLock { $0.apiKey } }
    static var baseURL: URL? { storage.withLock { $0.baseURL } }

    public static func configure(
        apiKey: String,
        baseURL: URL = URL(string: "https://trychatkit.com")!
    ) {
        storage.withLock { $0 = Config(apiKey: apiKey, baseURL: baseURL) }
    }

    @MainActor
    public static var store: ChatStore { ChatStore.shared }
}
