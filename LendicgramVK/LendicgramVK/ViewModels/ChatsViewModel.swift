import SwiftUI
import Combine

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published var items:    [VKConversationItem] = []
    @Published var profiles: [Int: VKUser]        = [:]
    @Published var groups:   [Int: VKGroup]       = [:]
    @Published var isLoading = false
    @Published var error: String?
    @Published var typingPeers: [Int: (name: String, deadline: Date)] = [:]

    private let api      = VKAPIService.shared
    private let longPoll = VKLongPollService.shared
    private var bag      = Set<AnyCancellable>()
    private var typingTimers: [Int: Task<Void, Never>] = [:]

    init() {
        longPoll.$newMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.onNewMessage(msg) }
            .store(in: &bag)

        longPoll.$onlineEvent
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                // Refresh profiles for online status update
                Task { await self.refreshUser(event.userId) }
            }
            .store(in: &bag)

        longPoll.$typingEvent
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleTyping(userId: event.userId, peerId: event.peerId)
            }
            .store(in: &bag)

        longPoll.$readInEvent
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                // Clear unread count for this peer
                guard let self = self,
                      let idx = self.items.firstIndex(where: { $0.conversation.peer.id == event.peerId })
                else { return }
                // Re-fetch to update unread counts
                Task { await self.fetch() }
            }
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
            r.profiles?.forEach { profiles[$0.id]  = $0 }
            r.groups?.forEach   { groups[-$0.id]   = $0 }
        } catch { self.error = error.localizedDescription }
    }

    private func refreshUser(_ userId: Int) async {
        do {
            let users = try await api.getUsers([userId])
            if let u = users.first { profiles[u.id] = u }
        } catch {}
    }

    private func onNewMessage(_ msg: VKAPIMessage) {
        // Clear typing for this peer
        typingPeers.removeValue(forKey: msg.peerId)
        typingTimers[msg.peerId]?.cancel()
        // Refresh conversations
        Task { await fetch() }
    }

    private func handleTyping(userId: Int, peerId: Int) {
        let name = profiles[userId]?.firstName ?? "..."
        typingPeers[peerId] = (name: name, deadline: Date().addingTimeInterval(6))
        typingTimers[peerId]?.cancel()
        typingTimers[peerId] = Task {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled {
                typingPeers.removeValue(forKey: peerId)
            }
        }
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

    func isOnline(for item: VKConversationItem) -> Bool {
        let peer = item.conversation.peer
        guard peer.type == "user" else { return false }
        return profiles[peer.id]?.isOnline ?? false
    }

    func isMobileOnline(for item: VKConversationItem) -> Bool {
        let peer = item.conversation.peer
        guard peer.type == "user" else { return false }
        return profiles[peer.id]?.isMobile ?? false
    }

    func lastMessagePreview(_ msg: VKAPIMessage?) -> String {
        guard let msg = msg else { return "" }
        // Service message
        if let action = msg.action {
            return serviceText(action, fromId: msg.fromId)
        }
        if !msg.text.isEmpty { return msg.text }
        guard let att = msg.attachments?.first else {
            if msg.fwdMessages?.isEmpty == false { return "Пересланные сообщения" }
            return ""
        }
        switch att.type {
        case "photo":         return "📷 Фотография"
        case "sticker":       return "🎭 Стикер"
        case "video":         return "🎬 Видео"
        case "audio_message": return "🎤 Голосовое"
        case "video_message": return "📹 Кружок"
        case "doc":           return "📎 \(att.doc?.title ?? "Документ")"
        case "audio":         return "🎵 \(att.audio?.artist ?? "") — \(att.audio?.title ?? "")"
        case "link":          return "🔗 \(att.link?.title ?? "Ссылка")"
        case "wall":          return "📝 Запись на стене"
        case "graffiti":      return "🖌 Граффити"
        case "gift":          return "🎁 Подарок"
        case "poll":          return "📊 \(att.poll?.question ?? "Опрос")"
        default:              return att.type.capitalized
        }
    }

    func serviceText(_ action: VKMessageAction, fromId: Int) -> String {
        let name = profiles[fromId]?.firstName ?? ""
        switch action.type {
        case "chat_create":          return "\(name) создал беседу"
        case "chat_invite_user":     return "\(name) пригласил пользователя"
        case "chat_kick_user":       return "\(name) исключил пользователя"
        case "chat_title_update":    return "\(name) изменил название"
        case "chat_photo_update":    return "\(name) обновил фото"
        case "chat_pin_message":     return "\(name) закрепил сообщение"
        case "chat_unpin_message":   return "\(name) открепил сообщение"
        default:                     return action.type
        }
    }

    func isTyping(for item: VKConversationItem) -> String? {
        guard let info = typingPeers[item.conversation.peer.id],
              info.deadline > Date() else { return nil }
        return "\(info.name) печатает..."
    }

    func deliveryStatus(for item: VKConversationItem) -> DeliveryStatus {
        guard let msg = item.lastMessage, msg.isOutgoing else { return .none }
        let outRead = item.conversation.outRead ?? 0
        if msg.id <= outRead { return .read }
        return .sent
    }

    enum DeliveryStatus { case none, sent, read }
}
