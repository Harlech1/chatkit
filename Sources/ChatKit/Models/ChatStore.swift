import Foundation
import Observation
import UIKit

private final class TaskBox: @unchecked Sendable {
    var task: Task<Void, Never>?
}

@MainActor
@Observable
public final class ChatStore {
    public static let shared = ChatStore()

    public private(set) var messages: [ChatMessage] = []
    public private(set) var unreadCount: Int = 0
    public var isProcessing: Bool = false

    @ObservationIgnored private let deviceId: String
    @ObservationIgnored private var lastFetched: Date?
    @ObservationIgnored private let pollBox = TaskBox()
    @ObservationIgnored private var isViewActive = false

    @ObservationIgnored
    private var lastReadAt: Date {
        get {
            (UserDefaults.standard.object(forKey: "ChatKit.lastReadAt") as? Date) ?? .distantPast
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ChatKit.lastReadAt")
        }
    }

    private init() {
        self.deviceId = DeviceID.get()
        startPolling()
    }

    deinit {
        pollBox.task?.cancel()
    }

    // MARK: - Public API

    public func send(text: String, image: UIImage? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || image != nil else { return }

        let local = ChatMessage(text: trimmed, isFromUser: true, image: image)
        appendMessage(local)

        let localId = local.id
        Task {
            do {
                let wire = try await ChatClient.shared.send(
                    text: trimmed,
                    image: image,
                    deviceId: deviceId
                )
                if let idx = messages.firstIndex(where: { $0.id == localId }) {
                    messages[idx].id = wire.id
                    messages[idx].timestamp = wire.createdAt
                    if let urlString = wire.imageUrl, let url = URL(string: urlString) {
                        messages[idx].imageUrl = url
                    }
                }
                lastFetched = max(lastFetched ?? .distantPast, wire.createdAt)
            } catch {
                print("ChatKit send failed: \(error)")
            }
        }
    }

    public func markAllRead() {
        lastReadAt = .now
        recomputeUnread()
    }

    // MARK: - Internal

    func setViewActive(_ active: Bool) {
        isViewActive = active
        if active {
            markAllRead()
        }
    }

    // MARK: - Private

    private func appendMessage(_ msg: ChatMessage) {
        messages.append(msg)
        if isViewActive {
            lastReadAt = .now
        }
        recomputeUnread()
    }

    private func recomputeUnread() {
        let cutoff = lastReadAt
        unreadCount = messages.reduce(into: 0) { count, msg in
            if !msg.isFromUser && msg.timestamp > cutoff {
                count += 1
            }
        }
    }

    private func startPolling() {
        pollBox.task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func pollOnce() async {
        guard ChatKit.apiKey != nil, ChatKit.baseURL != nil else { return }
        do {
            let wires = try await ChatClient.shared.fetch(since: lastFetched, deviceId: deviceId)
            for wire in wires {
                if messages.contains(where: { $0.id == wire.id }) { continue }
                let msg = ChatMessage(
                    id: wire.id,
                    text: wire.body,
                    isFromUser: wire.sender == "user",
                    imageUrl: wire.imageUrl.flatMap { URL(string: $0) },
                    timestamp: wire.createdAt
                )
                appendMessage(msg)
                lastFetched = max(lastFetched ?? .distantPast, wire.createdAt)
            }
        } catch {
            // silent — next poll will retry
        }
    }
}
