import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    let peerId: Int
    let peerName: String

    @Published var messages: [VKAPIMessage] = []
    @Published var profiles: [Int: VKUser]  = [:]
    @Published var groups:   [Int: VKGroup] = [:]
    @Published var isLoading  = false
    @Published var isSending  = false
    @Published var error: String?
    @Published var outRead: Int = 0           // last outgoing message read by peer
    @Published var typingUserIds: Set<Int> = []
    @Published var peerUser: VKUser?          // for 1-on-1 chats
    @Published var hasMore = true
    @Published var totalCount = 0

    private let api      = VKAPIService.shared
    private let longPoll = VKLongPollService.shared
    private var bag      = Set<AnyCancellable>()
    private var typingTimers: [Int: Task<Void, Never>] = [:]

    init(peerId: Int, peerName: String) {
        self.peerId   = peerId
        self.peerName = peerName

        // New message
        longPoll.$newMessage
            .compactMap { $0 }
            .filter { [peerId] in $0.peerId == peerId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.fetchLatest() }
            }
            .store(in: &bag)

        // Read event (they read our messages)
        longPoll.$readEvent
            .compactMap { $0 }
            .filter { [peerId] in $0.peerId == peerId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.outRead = max(self?.outRead ?? 0, event.msgId)
            }
            .store(in: &bag)

        // Online status
        longPoll.$onlineEvent
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                if var u = self.profiles[event.userId] {
                    // Can't mutate struct fields directly, re-fetch instead
                    Task { await self.refreshPeerUser() }
                }
                if event.userId == peerId {
                    Task { await self.refreshPeerUser() }
                }
            }
            .store(in: &bag)

        // Typing
        longPoll.$typingEvent
            .compactMap { $0 }
            .filter { [peerId] in $0.peerId == peerId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleTyping(userId: event.userId)
            }
            .store(in: &bag)
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        do {
            let r = try await api.getHistory(peerId: peerId)
            messages   = r.items.reversed()
            totalCount = r.count
            hasMore    = messages.count < totalCount
            r.profiles?.forEach { profiles[$0.id] = $0 }
            r.groups?.forEach   { groups[-$0.id]  = $0 }
        } catch { self.error = error.localizedDescription }
        isLoading = false

        // Fetch conversation to get outRead
        await fetchConversation()
        // Fetch peer user for online status
        await refreshPeerUser()
        // Mark as read
        await markAsRead()
        // Ensure LongPoll is running
        if !longPoll.isRunning {
            Task { await longPoll.start() }
        }
    }

    func fetchLatest() async {
        do {
            let r = try await api.getHistory(peerId: peerId, count: 20)
            let existingIds = Set(messages.map { $0.id })
            let newMsgs = r.items.reversed().filter { !existingIds.contains($0.id) }
            if !newMsgs.isEmpty {
                messages.append(contentsOf: newMsgs)
                r.profiles?.forEach { profiles[$0.id] = $0 }
                r.groups?.forEach   { groups[-$0.id]  = $0 }
            }
            // Mark new incoming as read
            if newMsgs.contains(where: { !$0.isOutgoing }) {
                await markAsRead()
            }
        } catch {}
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        do {
            let r = try await api.getHistory(peerId: peerId, offset: messages.count)
            let older = r.items.reversed()
            messages = older + messages
            totalCount = r.count
            hasMore = messages.count < totalCount
            r.profiles?.forEach { profiles[$0.id] = $0 }
            r.groups?.forEach   { groups[-$0.id]  = $0 }
        } catch {}
        isLoading = false
    }

    // MARK: - Send

    func send(text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSending = true
        do {
            let msgId = try await api.send(peerId: peerId, text: text)
            let uid   = VKAuthService.shared.currentUserId
            let optMsg = VKAPIMessage(
                id: msgId, fromId: uid, peerId: peerId,
                text: text, date: Int(Date().timeIntervalSince1970),
                out: 1,
                attachments: nil, replyMessage: nil, fwdMessages: nil,
                action: nil, updateTime: nil, important: nil
            )
            messages.append(optMsg)
        } catch { self.error = error.localizedDescription }
        isSending = false
    }

    func sendPhoto(imageData: Data) async {
        isSending = true
        do {
            let attachment = try await api.uploadPhotoForMessage(peerId: peerId, imageData: imageData)
            _ = try await api.sendWithAttachment(peerId: peerId, text: "", attachment: attachment)
            await fetchLatest()
        } catch { self.error = error.localizedDescription }
        isSending = false
    }

    // MARK: - Voice Message

    func sendVoice(fileURL: URL) async {
        isSending = true
        do {
            let attachment = try await api.uploadAudioMessage(peerId: peerId, fileURL: fileURL)
            _ = try await api.sendWithAttachment(peerId: peerId, text: "", attachment: attachment)
            await fetchLatest()
        } catch { self.error = error.localizedDescription }
        isSending = false
    }

    // MARK: - Video Message (кружок)

    func sendVideoMessage(fileURL: URL) async {
        isSending = true
        do {
            let attachment = try await api.uploadVideoMessage(peerId: peerId, fileURL: fileURL)
            _ = try await api.sendWithAttachment(peerId: peerId, text: "", attachment: attachment)
            await fetchLatest()
        } catch { self.error = error.localizedDescription }
        isSending = false
    }

    // MARK: - Stickers

    @Published var stickerPacks: [VKStickerProduct] = []

    func loadStickers() async {
        do {
            let r = try await api.getStickersProducts()
            stickerPacks = r.items
        } catch {}
    }

    func sendSticker(stickerId: Int) async {
        isSending = true
        do {
            _ = try await api.sendSticker(peerId: peerId, stickerId: stickerId)
            await fetchLatest()
        } catch { self.error = error.localizedDescription }
        isSending = false
    }

    // MARK: - Read

    func markAsRead() async {
        do { try await api.markAsRead(peerId: peerId) } catch {}
    }

    func fetchConversation() async {
        do {
            let r = try await api.getConversationsById(peerIds: [peerId])
            if let conv = r.items.first {
                outRead = conv.outRead ?? 0
            }
            r.profiles?.forEach { profiles[$0.id] = $0 }
        } catch {}
    }

    func refreshPeerUser() async {
        // Only for user peers (not group chats)
        guard peerId > 0 && peerId < 2_000_000_000 else { return }
        do {
            let users = try await api.getUsers([peerId])
            if let u = users.first {
                peerUser = u
                profiles[u.id] = u
            }
        } catch {}
    }

    // MARK: - Typing

    func handleTyping(userId: Int) {
        typingUserIds.insert(userId)
        typingTimers[userId]?.cancel()
        typingTimers[userId] = Task {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled {
                typingUserIds.remove(userId)
            }
        }
    }

    // MARK: - Helpers

    func isRead(_ msg: VKAPIMessage) -> Bool {
        msg.isOutgoing && msg.id <= outRead
    }

    func senderName(_ msg: VKAPIMessage) -> String {
        if let u = profiles[msg.fromId] { return u.firstName }
        if let g = groups[msg.fromId]   { return g.name }
        return ""
    }

    func shouldShowDate(at index: Int) -> Bool {
        guard index >= 0, index < messages.count else { return false }
        if index == 0 { return true }
        let cal = Calendar.current
        let prev = messages[index - 1].dateValue
        let curr = messages[index].dateValue
        return !cal.isDate(prev, inSameDayAs: curr)
    }

    var isGroupChat: Bool { peerId > 2_000_000_000 }
}
