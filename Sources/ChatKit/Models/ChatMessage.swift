import Foundation
import UIKit

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public var id: String
    public var text: String
    public var isFromUser: Bool
    public var image: UIImage?
    public var timestamp: Date

    public init(
        id: String = UUID().uuidString,
        text: String,
        isFromUser: Bool,
        image: UIImage? = nil,
        timestamp: Date = .now
    ) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.image = image
        self.timestamp = timestamp
    }

    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text
    }
}
