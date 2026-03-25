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
    let photo50: String?
    let photo100: String?
    let photo200: String?
    let online: Int?
    let onlineMobile: Int?
    let lastSeen: VKLastSeen?
    let sex: Int?           // 1 = female, 2 = male

    var fullName: String  { "\(firstName) \(lastName)" }
    var avatarURL: URL?   { URL(string: photo100 ?? photo50 ?? "") }
    var isOnline: Bool    { (online ?? 0) == 1 }
    var isMobile: Bool    { (onlineMobile ?? 0) == 1 }

    enum CodingKeys: String, CodingKey {
        case id; case firstName = "first_name"; case lastName = "last_name"
        case photo50 = "photo_50"; case photo100 = "photo_100"; case photo200 = "photo_200"
        case online; case onlineMobile = "online_mobile"
        case lastSeen = "last_seen"; case sex
    }

    var statusText: String {
        if isOnline { return isMobile ? "в сети с телефона" : "в сети" }
        guard let ls = lastSeen, let time = ls.time else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(time))
        let now  = Date()
        let diff = now.timeIntervalSince(date)
        let cal  = Calendar.current
        let pre  = (sex ?? 0) == 1 ? "была" : "был"

        if diff < 60   { return "\(pre) только что" }
        if diff < 3600 { return "\(pre) \(Int(diff / 60)) мин. назад" }

        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU")
        if cal.isDateInToday(date)     { f.dateFormat = "HH:mm"; return "\(pre) в \(f.string(from: date))" }
        if cal.isDateInYesterday(date) { f.dateFormat = "HH:mm"; return "\(pre) вчера в \(f.string(from: date))" }
        if diff < 7 * 86400           { f.dateFormat = "EEEE 'в' HH:mm"; return "\(pre) \(f.string(from: date))" }
        f.dateFormat = "d MMM 'в' HH:mm"
        return "\(pre) \(f.string(from: date))"
    }
}

struct VKLastSeen: Decodable {
    let time: Int?
    let platform: Int?
}

struct VKGroup: Decodable, Identifiable {
    let id: Int
    let name: String
    let photo50: String?
    let photo100: String?
    let photo200: String?
    var avatarURL: URL? { URL(string: photo100 ?? photo50 ?? "") }
    enum CodingKeys: String, CodingKey {
        case id; case name
        case photo50 = "photo_50"; case photo100 = "photo_100"; case photo200 = "photo_200"
    }
}

// MARK: - Conversations

struct VKConversationsResponse: Decodable {
    let count: Int
    let items: [VKConversationItem]
    let profiles: [VKUser]?
    let groups: [VKGroup]?
}

struct VKConversationsByIdResponse: Decodable {
    let count: Int
    let items: [VKConversation]
    let profiles: [VKUser]?
}

struct VKConversationItem: Decodable, Identifiable {
    var id: Int { conversation.peer.id }
    var conversation: VKConversation
    var lastMessage: VKAPIMessage?
    enum CodingKeys: String, CodingKey { case conversation; case lastMessage = "last_message" }
}

struct VKConversation: Decodable {
    let peer: VKPeer
    let inRead: Int?
    var outRead: Int?
    let lastMessageId: Int?
    var unreadCount: Int?
    let isPinned: Bool?
    let isMarkedUnread: Bool?
    let canSendMessage: Bool?
    let chatSettings: VKChatSettings?
    enum CodingKeys: String, CodingKey {
        case peer
        case inRead = "in_read"; case outRead = "out_read"
        case lastMessageId = "last_message_id"
        case unreadCount = "unread_count"; case isPinned = "is_pinned"
        case isMarkedUnread = "is_marked_unread"
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
    let activeIds: [Int]?
    let state: String?
    enum CodingKeys: String, CodingKey {
        case title; case membersCount = "members_count"; case photo
        case activeIds = "active_ids"; case state
    }
}

struct VKChatPhoto: Decodable {
    let photo50: String?
    let photo100: String?
    let photo200: String?
    var url: URL? { URL(string: photo100 ?? photo50 ?? "") }
    enum CodingKeys: String, CodingKey {
        case photo50 = "photo_50"; case photo100 = "photo_100"; case photo200 = "photo_200"
    }
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
    let attachments: [VKAttachment]?
    let replyMessage: VKReplyMessage?
    let fwdMessages: [VKReplyMessage]?
    let action: VKMessageAction?
    let updateTime: Int?
    let important: Bool?

    var isOutgoing: Bool { out == 1 }
    var isEdited: Bool   { (updateTime ?? 0) > 0 }
    var isService: Bool  { action != nil }
    var dateValue: Date  { Date(timeIntervalSince1970: TimeInterval(date)) }

    enum CodingKeys: String, CodingKey {
        case id; case fromId = "from_id"; case peerId = "peer_id"
        case text; case date; case out
        case attachments; case replyMessage = "reply_message"
        case fwdMessages = "fwd_messages"; case action
        case updateTime = "update_time"; case important
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(Int.self, forKey: .id)
        fromId       = try c.decode(Int.self, forKey: .fromId)
        peerId       = try c.decode(Int.self, forKey: .peerId)
        text         = (try? c.decode(String.self, forKey: .text)) ?? ""
        date         = try c.decode(Int.self, forKey: .date)
        out          = (try? c.decode(Int.self, forKey: .out)) ?? 0
        attachments  = try? c.decodeIfPresent([VKAttachment].self, forKey: .attachments)
        replyMessage = try? c.decodeIfPresent(VKReplyMessage.self, forKey: .replyMessage)
        fwdMessages  = try? c.decodeIfPresent([VKReplyMessage].self, forKey: .fwdMessages)
        action       = try? c.decodeIfPresent(VKMessageAction.self, forKey: .action)
        updateTime   = try? c.decodeIfPresent(Int.self, forKey: .updateTime)
        important    = try? c.decodeIfPresent(Bool.self, forKey: .important)
    }

    // Manual init for creating messages in code (send, LongPoll)
    init(id: Int, fromId: Int, peerId: Int, text: String, date: Int, out: Int,
         attachments: [VKAttachment]?, replyMessage: VKReplyMessage?,
         fwdMessages: [VKReplyMessage]?, action: VKMessageAction?,
         updateTime: Int?, important: Bool?) {
        self.id = id; self.fromId = fromId; self.peerId = peerId
        self.text = text; self.date = date; self.out = out
        self.attachments = attachments; self.replyMessage = replyMessage
        self.fwdMessages = fwdMessages; self.action = action
        self.updateTime = updateTime; self.important = important
    }
}

struct VKReplyMessage: Decodable, Identifiable {
    let id: Int
    let fromId: Int
    let peerId: Int?
    let text: String
    let date: Int
    let attachments: [VKAttachment]?
    enum CodingKeys: String, CodingKey {
        case id; case fromId = "from_id"; case peerId = "peer_id"
        case text; case date; case attachments
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(Int.self, forKey: .id)
        fromId      = (try? c.decode(Int.self, forKey: .fromId)) ?? 0
        peerId      = try? c.decodeIfPresent(Int.self, forKey: .peerId)
        text        = (try? c.decode(String.self, forKey: .text)) ?? ""
        date        = (try? c.decode(Int.self, forKey: .date)) ?? 0
        attachments = try? c.decodeIfPresent([VKAttachment].self, forKey: .attachments)
    }
}

struct VKMessageAction: Decodable {
    let type: String        // chat_create, chat_invite_user, chat_kick_user, chat_title_update, chat_photo_update, chat_pin_message, chat_unpin_message
    let memberId: Int?
    let text: String?
    let email: String?
    enum CodingKeys: String, CodingKey {
        case type; case memberId = "member_id"; case text; case email
    }
}

// MARK: - Attachments

struct VKAttachment: Decodable {
    let type: String
    let photo: VKPhoto?
    let video: VKVideo?
    let audio: VKAudio?
    let doc: VKDoc?
    let link: VKLink?
    let sticker: VKSticker?
    let gift: VKGift?
    let wall: VKWall?
    let graffiti: VKGraffiti?
    let poll: VKPoll?
    let audioMessage: VKAudioMessage?
    let videoMessage: VKVideoMessage?

    enum CodingKeys: String, CodingKey {
        case type; case photo; case video; case audio; case doc; case link
        case sticker; case gift; case wall; case graffiti; case poll
        case audioMessage = "audio_message"
        case videoMessage = "video_message"
    }

    // Defensive decoder: if any attachment sub-type fails, it becomes nil
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type         = try c.decode(String.self, forKey: .type)
        photo        = try? c.decodeIfPresent(VKPhoto.self, forKey: .photo)
        video        = try? c.decodeIfPresent(VKVideo.self, forKey: .video)
        audio        = try? c.decodeIfPresent(VKAudio.self, forKey: .audio)
        doc          = try? c.decodeIfPresent(VKDoc.self, forKey: .doc)
        link         = try? c.decodeIfPresent(VKLink.self, forKey: .link)
        sticker      = try? c.decodeIfPresent(VKSticker.self, forKey: .sticker)
        gift         = try? c.decodeIfPresent(VKGift.self, forKey: .gift)
        wall         = try? c.decodeIfPresent(VKWall.self, forKey: .wall)
        graffiti     = try? c.decodeIfPresent(VKGraffiti.self, forKey: .graffiti)
        poll         = try? c.decodeIfPresent(VKPoll.self, forKey: .poll)
        audioMessage = try? c.decodeIfPresent(VKAudioMessage.self, forKey: .audioMessage)
        videoMessage = try? c.decodeIfPresent(VKVideoMessage.self, forKey: .videoMessage)
    }
}

struct VKPhoto: Decodable {
    let id: Int?
    let ownerId: Int?
    let sizes: [VKPhotoSize]?
    let text: String?
    var bestURL: URL? {
        for t in ["x","y","z","w","r","q","p","o","m","s"] {
            if let s = sizes?.first(where: { $0.type == t }), let url = URL(string: s.url) { return url }
        }
        return sizes?.last.flatMap { URL(string: $0.url) }
    }
    var thumbURL: URL? {
        for t in ["m","s","o","p","q","r","x"] {
            if let s = sizes?.first(where: { $0.type == t }), let url = URL(string: s.url) { return url }
        }
        return bestURL
    }
    var aspectRatio: CGFloat {
        guard let best = sizes?.first(where: { ["x","y","z","w"].contains($0.type) }),
              let w = best.width, let h = best.height, h > 0 else { return 1.0 }
        return CGFloat(w) / CGFloat(h)
    }
    enum CodingKeys: String, CodingKey {
        case id; case ownerId = "owner_id"; case sizes; case text
    }
}

struct VKPhotoSize: Decodable {
    let type: String
    let url: String
    let width: Int?
    let height: Int?
}

struct VKVideo: Decodable {
    let id: Int?
    let ownerId: Int?
    let accessKey: String?
    let title: String?
    let duration: Int?
    let player: String?
    let files: VKVideoFiles?
    let image: [VKVideoImage]?
    let firstFrame: [VKVideoImage]?
    var thumbURL: URL? {
        let imgs = image ?? firstFrame ?? []
        return imgs.max(by: { ($0.width ?? 0) < ($1.width ?? 0) })
            .flatMap { URL(string: $0.url) }
    }
    var durationFormatted: String {
        guard let d = duration else { return "" }
        let m = d / 60; let s = d % 60
        return String(format: "%d:%02d", m, s)
    }
    var bestFileURL: URL? {
        guard let f = files else { return nil }
        let candidates = [f.mp4_1080, f.mp4_720, f.mp4_480, f.mp4_360, f.mp4_240, f.hls]
        return candidates.compactMap { $0 }.compactMap { URL(string: $0) }.first
    }
    enum CodingKeys: String, CodingKey {
        case id; case ownerId = "owner_id"; case accessKey = "access_key"
        case title; case duration; case player; case files
        case image; case firstFrame = "first_frame"
    }
}

struct VKVideoFiles: Decodable {
    let mp4_240: String?
    let mp4_360: String?
    let mp4_480: String?
    let mp4_720: String?
    let mp4_1080: String?
    let hls: String?
}

struct VKVideoImage: Decodable {
    let url: String; let width: Int?; let height: Int?
}

struct VKVideoListResponse: Decodable {
    let count: Int
    let items: [VKVideo]
}

struct VKAudio: Decodable {
    let id: Int?
    let ownerId: Int?
    let artist: String?
    let title: String?
    let duration: Int?
    var durationFormatted: String {
        guard let d = duration else { return "" }
        return String(format: "%d:%02d", d / 60, d % 60)
    }
    enum CodingKeys: String, CodingKey {
        case id; case ownerId = "owner_id"; case artist; case title; case duration
    }
}

struct VKDoc: Decodable {
    let id: Int?
    let ownerId: Int?
    let title: String?
    let size: Int?
    let ext: String?
    let url: String?
    let preview: VKDocPreview?
    var sizeFormatted: String {
        guard let s = size else { return "" }
        if s < 1024            { return "\(s) Б" }
        if s < 1024 * 1024     { return "\(s / 1024) КБ" }
        return String(format: "%.1f МБ", Double(s) / 1_048_576.0)
    }
    var displayTitle: String { title ?? "Документ" }
    enum CodingKeys: String, CodingKey {
        case id; case ownerId = "owner_id"; case title; case size
        case ext; case url; case preview
    }
}

struct VKDocPreview: Decodable {
    let photo: VKDocPreviewPhoto?
    let graffiti: VKDocPreviewGraffiti?
}
struct VKDocPreviewPhoto: Decodable { let sizes: [VKPhotoSize]? }
struct VKDocPreviewGraffiti: Decodable {
    let src: String?
    var url: URL? { URL(string: src ?? "") }
}

struct VKLink: Decodable {
    let url: String?
    let title: String?
    let caption: String?
    let description: String?
    let photo: VKPhoto?
}

struct VKSticker: Decodable {
    let stickerId: Int?
    let productId: Int?
    let images: [VKStickerImage]?
    let imagesWithBackground: [VKStickerImage]?
    let animationUrl: String?
    var bestURL: URL? {
        // Use transparent images; fall back to background variants only if needed
        let imgs = images ?? imagesWithBackground ?? []
        if let best = imgs.max(by: { $0.width < $1.width }),
           let url = URL(string: best.url) {
            return url
        }
        // Fallback: VK serves sticker PNGs at this well-known URL pattern
        if let sid = stickerId {
            return URL(string: "https://vk.com/sticker/1-\(sid)-256")
        }
        return nil
    }
    enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"; case productId = "product_id"
        case images; case imagesWithBackground = "images_with_background"
        case animationUrl = "animation_url"
    }
}
struct VKStickerImage: Decodable {
    let url: String
    let width: Int
    let height: Int
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url    = (try? c.decode(String.self, forKey: .url)) ?? ""
        width  = (try? c.decode(Int.self, forKey: .width)) ?? 0
        height = (try? c.decode(Int.self, forKey: .height)) ?? 0
    }
    enum CodingKeys: String, CodingKey { case url; case width; case height }
}

struct VKGift: Decodable {
    let id: Int
    let thumb256: String?
    let thumb96: String?
    var thumbURL: URL? { URL(string: thumb256 ?? thumb96 ?? "") }
    enum CodingKeys: String, CodingKey {
        case id; case thumb256 = "thumb_256"; case thumb96 = "thumb_96"
    }
}

struct VKWall: Decodable {
    let id: Int?
    let fromId: Int?
    let text: String?
    let attachments: [VKAttachment]?
    enum CodingKeys: String, CodingKey {
        case id; case fromId = "from_id"; case text; case attachments
    }
}

struct VKGraffiti: Decodable {
    let id: Int?
    let url: String?
    let width: Int?
    let height: Int?
    var imageURL: URL? { URL(string: url ?? "") }
}

struct VKPoll: Decodable {
    let id: Int?
    let ownerId: Int?
    let question: String?
    let votes: Int?
    let answers: [VKPollAnswer]?
    let anonymous: Bool?
    let multiple: Bool?
    enum CodingKeys: String, CodingKey {
        case id; case ownerId = "owner_id"; case question; case votes
        case answers; case anonymous; case multiple
    }
}
struct VKPollAnswer: Decodable, Identifiable {
    let id: Int
    let text: String?
    let votes: Int?
    let rate: Double?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id    = (try? c.decode(Int.self, forKey: .id)) ?? Int.random(in: 1...999_999)
        text  = try? c.decodeIfPresent(String.self, forKey: .text)
        votes = try? c.decodeIfPresent(Int.self, forKey: .votes)
        rate  = try? c.decodeIfPresent(Double.self, forKey: .rate)
    }
    enum CodingKeys: String, CodingKey { case id; case text; case votes; case rate }
}

struct VKAudioMessage: Decodable {
    let id: Int?
    let ownerId: Int?
    let duration: Int?
    let waveform: [Int]?
    let linkOgg: String?
    let linkMp3: String?
    let transcript: String?
    enum CodingKeys: String, CodingKey {
        case id; case ownerId = "owner_id"; case duration; case waveform
        case linkOgg = "link_ogg"; case linkMp3 = "link_mp3"; case transcript
    }
}

struct VKVideoMessage: Decodable {
    let id: Int?
    let ownerId: Int?
    let duration: Int?
    let preview: [VKVideoMessagePreview]?
    let url: String?
    let link: String?
    let accessKey: String?
    var previewURL: URL? {
        preview?.max(by: { ($0.width ?? 0) < ($1.width ?? 0) })
            .flatMap { URL(string: $0.src) }
    }
    /// VK returns the direct mp4 link as either "url" or "link"
    var videoURL: String? { url ?? link }
    enum CodingKeys: String, CodingKey {
        case id; case ownerId = "owner_id"; case duration
        case preview; case url; case link; case accessKey = "access_key"
    }
}
struct VKVideoMessagePreview: Decodable {
    let src: String; let width: Int?; let height: Int?
}

// MARK: - Friends

struct VKFriendsResponse: Decodable {
    let count: Int
    let items: [VKUser]
}

// MARK: - Long Poll

struct VKLongPollServer: Decodable { let server: String; let key: String; let ts: String }

struct VKLongPollResponse: Decodable {
    let ts: String
    let updates: [[LPValue]]?
    let failed: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .ts) { ts = s }
        else if let i = try? c.decode(Int.self, forKey: .ts) { ts = String(i) }
        else { ts = "0" }
        updates = try? c.decodeIfPresent([[LPValue]].self, forKey: .updates)
        failed  = try? c.decodeIfPresent(Int.self, forKey: .failed)
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

// MARK: - Sticker Products

struct VKStickerProduct: Decodable, Identifiable {
    let id: Int
    let title: String?
    let stickers: [VKProductSticker]?
    let previews: [VKStickerImage]?

    enum CodingKeys: String, CodingKey { case id; case title; case stickers; case previews }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id    = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        previews = try c.decodeIfPresent([VKStickerImage].self, forKey: .previews)
        // VK returns stickers as {"count":N,"items":[...]} — unwrap the wrapper
        if let wrapper = try? c.decode(VKProductStickersWrapper.self, forKey: .stickers) {
            stickers = wrapper.items
        } else {
            // Also try plain array just in case
            stickers = try? c.decode([VKProductSticker].self, forKey: .stickers)
        }
    }
}

/// VK wraps stickers inside {"count":N,"items":[...]}
private struct VKProductStickersWrapper: Decodable {
    let items: [VKProductSticker]
}

struct VKProductSticker: Decodable, Identifiable {
    let stickerId: Int
    let images: [VKStickerImage]?
    let imagesWithBackground: [VKStickerImage]?
    var id: Int { stickerId }
    /// Prefer transparent images; fall back to with-background; last resort — VK URL pattern
    var bestURL: URL? {
        // Prefer transparent (no background)
        if let imgs = images, !imgs.isEmpty,
           let best = imgs.max(by: { $0.width < $1.width }),
           let url = URL(string: best.url) {
            return url
        }
        if let imgs = imagesWithBackground, !imgs.isEmpty,
           let best = imgs.max(by: { $0.width < $1.width }),
           let url = URL(string: best.url) {
            return url
        }
        // Fallback URL pattern
        return URL(string: "https://vk.com/sticker/1-\(stickerId)-128")
    }
    enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"; case images
        case imagesWithBackground = "images_with_background"
    }
}

struct VKStickersResponse: Decodable {
    let count: Int
    let items: [VKStickerProduct]
}

// MARK: - Time formatting

extension Int {
    var vkTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(self))
        let now  = Date()
        let diff = now.timeIntervalSince(date)
        if diff < 60 { return "сейчас" }
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

    var vkDateSeparator: String {
        let date = Date(timeIntervalSince1970: TimeInterval(self))
        let cal  = Calendar.current
        if cal.isDateInToday(date)     { return "Сегодня" }
        if cal.isDateInYesterday(date) { return "Вчера" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }
}
