import Foundation
import Observation
import UIKit

private final class TaskBox: @unchecked Sendable {
    var task: Task<Void, Never>?
}

@MainActor
@Observable
public final class ChatStore {
    public var messages: [ChatMessage] = []
    public var isProcessing: Bool = false

    @ObservationIgnored private let deviceId: String
    @ObservationIgnored private var lastFetched: Date?
    @ObservationIgnored private let pollBox = TaskBox()

    public init() {
        self.deviceId = DeviceID.get()
        startPolling()
    }

    deinit {
        pollBox.task?.cancel()
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
