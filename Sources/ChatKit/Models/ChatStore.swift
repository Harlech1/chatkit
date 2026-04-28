import Foundation
import Observation
import UIKit

@MainActor
@Observable
public final class ChatStore {
    public var messages: [ChatMessage] = []
    public var isProcessing: Bool = false

    public init() {}

    public func send(text: String, image: UIImage? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || image != nil else { return }

        let message = ChatMessage(text: trimmed, isFromUser: true, image: image)
        messages.append(message)
    }
}
