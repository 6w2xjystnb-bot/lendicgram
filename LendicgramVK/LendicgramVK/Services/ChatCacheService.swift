import Foundation

/// Caches raw API JSON responses to disk for instant display on open
final class ChatCache: @unchecked Sendable {
    static let shared = ChatCache()

    private let cacheDir: URL
    private let queue = DispatchQueue(label: "vk.chat-cache.io", qos: .utility)
    private let decoder = JSONDecoder()

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = caches.appendingPathComponent("VKChatCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Messages (raw JSON)

    struct CachedMessages {
        let messages: [VKAPIMessage]
        let totalCount: Int
    }

    func saveMessagesData(_ data: Data, peerId: Int) {
        queue.async { [cacheDir] in
            let file = cacheDir.appendingPathComponent("chat_\(peerId).json")
            try? data.write(to: file)
        }
    }

    func loadMessages(peerId: Int) -> CachedMessages? {
        let file = cacheDir.appendingPathComponent("chat_\(peerId).json")
        guard let data = try? Data(contentsOf: file),
              let resp = try? decoder.decode(VKResponse<VKMessagesResponse>.self, from: data) else { return nil }
        return CachedMessages(messages: resp.response.items.reversed(), totalCount: resp.response.count)
    }

    // MARK: - Conversations (raw JSON)

    struct CachedConversations {
        let items: [VKConversationItem]
        let profiles: [VKUser]
        let groups: [VKGroup]
    }

    func saveConversationsData(_ data: Data) {
        queue.async { [cacheDir] in
            let file = cacheDir.appendingPathComponent("conversations.json")
            try? data.write(to: file)
        }
    }

    func loadConversations() -> CachedConversations? {
        let file = cacheDir.appendingPathComponent("conversations.json")
        guard let data = try? Data(contentsOf: file),
              let resp = try? decoder.decode(VKResponse<VKConversationsResponse>.self, from: data) else { return nil }
        return CachedConversations(
            items: resp.response.items,
            profiles: resp.response.profiles ?? [],
            groups: resp.response.groups ?? []
        )
    }
}
