import Foundation

// MARK: - Generic wrapper

struct VKResponse<T: Decodable>: Decodable { let response: T }
struct VKErrorResponse: Decodable { let error: VKError }
struct VKError: Decodable {
    let errorCode: Int; let errorMsg: String
    enum CodingKeys: String, CodingKey { case errorCode = "error_code"; case errorMsg = "error_msg" }
}

enum VKAPIError: LocalizedError {
    case invalidURL, httpError, emptyResponse, apiError(code: Int, msg: String)
    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Неверный URL"
        case .httpError:           return "Ошибка соединения"
        case .emptyResponse:       return "Пустой ответ"
        case .apiError(_, let m):  return "VK: \(m)"
        }
    }
}

// MARK: - User / Group

struct VKUser: Decodable, Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let photo100: String?
    let online: Int?
    var fullName: String  { "\(firstName) \(lastName)" }
    var avatarURL: URL?   { URL(string: photo100 ?? "") }
    enum CodingKeys: String, CodingKey {
        case id; case firstName = "first_name"; case lastName = "last_name"
        case photo100 = "photo_100"; case online
    }
}

struct VKGroup: Decodable, Identifiable {
    let id: Int
    let name: String
    let photo100: String?
    var avatarURL: URL? { URL(string: photo100 ?? "") }
    enum CodingKeys: String, CodingKey { case id; case name; case photo100 = "photo_100" }
}

// MARK: - Conversations

struct VKConversationsResponse: Decodable {
    let count: Int
    let items: [VKConversationItem]
    let profiles: [VKUser]?
    let groups: [VKGroup]?
}

struct VKConversationItem: Decodable, Identifiable {
    var id: Int { conversation.peer.id }
    let conversation: VKConversation
    let lastMessage: VKAPIMessage?
    enum CodingKeys: String, CodingKey { case conversation; case lastMessage = "last_message" }
}

struct VKConversation: Decodable {
    let peer: VKPeer
    let unreadCount: Int?
    let isPinned: Bool?
    let canSendMessage: Bool?
    let chatSettings: VKChatSettings?
    enum CodingKeys: String, CodingKey {
        case peer; case unreadCount = "unread_count"; case isPinned = "is_pinned"
        case canSendMessage = "can_send_message"; case chatSettings = "chat_settings"
    }
}

struct VKPeer: Decodable {
    let id: Int; let type: String; let localId: Int
    enum CodingKeys: String, CodingKey { case id; case type; case localId = "local_id" }
}

struct VKChatSettings: Decodable {
    let title: String
    let membersCount: Int?
    let photo: VKChatPhoto?
    enum CodingKeys: String, CodingKey {
        case title; case membersCount = "members_count"; case photo
    }
}

struct VKChatPhoto: Decodable {
    let photo100: String?
    var url: URL? { URL(string: photo100 ?? "") }
    enum CodingKeys: String, CodingKey { case photo100 = "photo_100" }
}

// MARK: - Messages

struct VKMessagesResponse: Decodable {
    let count: Int
    let items: [VKAPIMessage]
    let profiles: [VKUser]?
    let groups: [VKGroup]?
}

struct VKAPIMessage: Decodable, Identifiable {
    let id: Int
    let fromId: Int
    let peerId: Int
    let text: String
    let date: Int
    let out: Int
    let readState: Int?
    let attachments: [VKAttachment]?
    var isOutgoing: Bool { out == 1 }
    var isRead: Bool     { readState == 1 }
    var dateValue: Date  { Date(timeIntervalSince1970: TimeInterval(date)) }
    enum CodingKeys: String, CodingKey {
        case id; case fromId = "from_id"; case peerId = "peer_id"
        case text; case date; case out; case readState = "read_state"; case attachments
    }
}

// MARK: - Attachments

struct VKAttachment: Decodable {
    let type: String
    let photo: VKPhoto?
    let sticker: VKSticker?
    let doc: VKDoc?
    let video: VKVideo?
    let audioMessage: VKAudioMessage?
    let videoMessage: VKVideoMessage?
    enum CodingKeys: String, CodingKey {
        case type; case photo; case sticker; case doc; case video
        case audioMessage = "audio_message"
        case videoMessage = "video_message"
    }
}

struct VKPhoto: Decodable {
    let sizes: [VKPhotoSize]?
    var bestURL: URL? {
        for t in ["x","y","z","w","r","q","p","o","m","s"] {
            if let s = sizes?.first(where: { $0.type == t }), let url = URL(string: s.url) { return url }
        }
        return nil
    }
}
struct VKPhotoSize: Decodable { let type: String; let url: String }

struct VKSticker: Decodable {
    let stickerId: Int?
    let imagesWithBackground: [VKStickerImage]?
    var bestURL: URL? {
        (imagesWithBackground ?? []).max(by: { $0.width < $1.width })
            .flatMap { URL(string: $0.url) }
    }
    enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"; case imagesWithBackground = "images_with_background"
    }
}
struct VKStickerImage: Decodable { let url: String; let width: Int; let height: Int }

struct VKDoc: Decodable { let id: Int; let title: String; let ext: String? }
struct VKVideo: Decodable { let id: Int; let title: String }
struct VKAudioMessage: Decodable {
    let duration: Int?
    let linkMp3: String?
    enum CodingKeys: String, CodingKey { case duration; case linkMp3 = "link_mp3" }
}

struct VKVideoMessage: Decodable {
    let duration: Int?
    let previewUrl: String?
    let linkMp4: String?
    var previewURL: URL? { URL(string: previewUrl ?? "") }
    enum CodingKeys: String, CodingKey {
        case duration; case previewUrl = "preview_url"; case linkMp4 = "link_mp4"
    }
}

// MARK: - Long Poll

struct VKLongPollServer: Decodable { let server: String; let key: String; let ts: String }

struct VKLongPollResponse: Decodable {
    let ts: String
    let updates: [[LPValue]]?
    let failed: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .ts) {
            ts = s
        } else {
            ts = String(try c.decode(Int.self, forKey: .ts))
        }
        updates = try? c.decodeIfPresent([[LPValue]].self, forKey: .updates) ?? nil
        failed  = try? c.decodeIfPresent(Int.self, forKey: .failed) ?? nil
    }
    enum CodingKeys: String, CodingKey { case ts, updates, failed }
}

enum LPValue: Decodable {
    case int(Int), string(String), unknown
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self)    { self = .int(i);    return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .unknown
    }
    var intValue:    Int?    { if case .int(let i)    = self { return i }; return nil }
    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
}

// MARK: - Time formatting

extension Int {
    var vkTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(self))
        let now  = Date()
        let diff = now.timeIntervalSince(date)
        if diff < 60   { return "сейчас" }
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
        }
        if cal.isDateInYesterday(date) { return "вчера" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = date > now.addingTimeInterval(-7*86400) ? "EEE" : "d MMM"
        return f.string(from: date)
    }
}
