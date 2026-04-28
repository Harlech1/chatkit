import Foundation
import Observation
import UIKit

@MainActor
@Observable
public final class ChatStore {
    public var messages: [ChatMessage] = []
    public var isProcessing: Bool = false

    private let deviceId: String
    private var lastFetched: Date?
    private var pollTask: Task<Void, Never>?

    public init() {
        self.deviceId = DeviceID.get()
        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    public func send(text: String, image: UIImage? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || image != nil else { return }

        let local = ChatMessage(text: trimmed, isFromUser: true, image: image)
        messages.append(local)

        guard !trimmed.isEmpty else { return }

        let localId = local.id
        Task {
            do {
                let wire = try await ChatClient.shared.send(text: trimmed, deviceId: deviceId)
                if let idx = messages.firstIndex(where: { $0.id == localId }) {
                    messages[idx].id = wire.id
                    messages[idx].timestamp = wire.createdAt
                }
                lastFetched = max(lastFetched ?? .distantPast, wire.createdAt)
            } catch {
                print("ChatKit send failed: \(error)")
            }
        }
    }

    private func startPolling() {
        pollTask = Task { [weak self] in
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
                    timestamp: wire.createdAt
                )
                messages.append(msg)
                lastFetched = max(lastFetched ?? .distantPast, wire.createdAt)
            }
        } catch {
            // silent — next poll will retry
        }
    }
}
