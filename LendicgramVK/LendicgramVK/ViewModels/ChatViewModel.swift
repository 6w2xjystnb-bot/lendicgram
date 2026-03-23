import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    let peerId: Int
    let peerName: String

    @Published var messages: [VKAPIMessage] = []
    @Published var profiles: [Int: VKUser]  = [:]
    @Published var isLoading  = false
    @Published var isSending  = false
    @Published var error: String?

    private let api      = VKAPIService.shared
    private let longPoll = VKLongPollService.shared
    private var bag      = Set<AnyCancellable>()

    init(peerId: Int, peerName: String) {
        self.peerId   = peerId
        self.peerName = peerName

        longPoll.$newMessage
            .compactMap { $0 }
            .filter { $0.peerId == peerId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.fetchLatest() }
            }
            .store(in: &bag)
    }

    func load() async {
        isLoading = true
        do {
            let r    = try await api.getHistory(peerId: peerId)
            messages = r.items.reversed()
            r.profiles?.forEach { profiles[$0.id] = $0 }
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func fetchLatest() async {
        do {
            let r = try await api.getHistory(peerId: peerId, count: 10)
            let existingIds = Set(messages.map { $0.id })
            let newMsgs = r.items.reversed().filter { !existingIds.contains($0.id) }
            if !newMsgs.isEmpty {
                messages.append(contentsOf: newMsgs)
                r.profiles?.forEach { profiles[$0.id] = $0 }
            }
        } catch {}
    }

    func loadMore() async {
        guard !isLoading, messages.count > 0 else { return }
        do {
            let r    = try await api.getHistory(peerId: peerId, offset: messages.count)
            messages = r.items.reversed() + messages
            r.profiles?.forEach { profiles[$0.id] = $0 }
        } catch {}
    }

    func send(text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSending = true
        do {
            let msgId  = try await api.send(peerId: peerId, text: text)
            let uid    = VKAuthService.shared.currentUserId
            let optMsg = VKAPIMessage(
                id: msgId, fromId: uid, peerId: peerId,
                text: text, date: Int(Date().timeIntervalSince1970),
                out: 1, attachments: nil
            )
            messages.append(optMsg)
        } catch { self.error = error.localizedDescription }
        isSending = false
    }

    // Helper: first letter for avatar fallback
    func initials(fromId: Int) -> String {
        guard let u = profiles[fromId] else { return "?" }
        return String((u.firstName.first ?? "?")) + String((u.lastName.first ?? "?"))
    }
}
