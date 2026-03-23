import SwiftUI
import Combine

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published var items:    [VKConversationItem] = []
    @Published var profiles: [Int: VKUser]        = [:]
    @Published var groups:   [Int: VKGroup]       = [:]
    @Published var isLoading = false
    @Published var error: String?

    private let api      = VKAPIService.shared
    private let longPoll = VKLongPollService.shared
    private var bag      = Set<AnyCancellable>()

    init() {
        longPoll.$newMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.onNewMessage(msg) }
            .store(in: &bag)
    }

    func load() async {
        isLoading = true
        await fetch()
        isLoading = false
        Task { await longPoll.start() }
    }

    func refresh() async { await fetch() }

    private func fetch() async {
        do {
            let r = try await api.getConversations()
            items = r.items
            r.profiles?.forEach { profiles[$0.id]    = $0 }
            r.groups?.forEach   { groups[-$0.id]     = $0 }
        } catch { self.error = error.localizedDescription }
    }

    private func onNewMessage(_ msg: VKAPIMessage) {
        // Bring peer conversation to top
        if let idx = items.firstIndex(where: { $0.conversation.peer.id == msg.peerId }) {
            let item = items.remove(at: idx)
            items.insert(item, at: 0)
        }
        Task { await fetch() }
    }

    // MARK: - Display helpers

    func displayName(for item: VKConversationItem) -> String {
        let peer = item.conversation.peer
        switch peer.type {
        case "user":  return profiles[peer.id]?.fullName ?? "Пользователь \(peer.id)"
        case "group": return groups[peer.id]?.name       ?? "Сообщество"
        case "chat":  return item.conversation.chatSettings?.title ?? "Беседа"
        default:      return "Диалог"
        }
    }

    func avatarURL(for item: VKConversationItem) -> URL? {
        let peer = item.conversation.peer
        switch peer.type {
        case "user":  return profiles[peer.id]?.avatarURL
        case "group": return groups[peer.id]?.avatarURL
        case "chat":  return item.conversation.chatSettings?.photo?.url
        default:      return nil
        }
    }

    func lastMessagePreview(_ msg: VKAPIMessage?) -> String {
        guard let msg = msg else { return "" }
        if !msg.text.isEmpty { return msg.text }
        guard let att = msg.attachments?.first else { return "" }
        switch att.type {
        case "photo":         return "📷 Фотография"
        case "sticker":       return "🎭 Стикер"
        case "video":         return "🎬 Видео"
        case "audio_message": return "🎤 Голосовое"
        case "video_message": return "📹 Кружок"
        case "doc":           return "📎 \(att.doc?.title ?? "Документ")"
        default:              return att.type.capitalized
        }
    }
}
