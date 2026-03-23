import SwiftUI

// MARK: - Chat Models

enum ChatType {
    case personal, group, channel, bot
}

struct VKChat: Identifiable {
    let id: UUID = UUID()
    let name: String
    let avatarColor: Color
    let avatarEmoji: String?
    let lastMessage: String
    let time: String
    let isPinned: Bool
    let isRead: Bool
    let isSentByMe: Bool
    let isDelivered: Bool
    let isDoubleCheck: Bool
    let chatType: ChatType
    let unreadCount: Int
    let lastMessageType: MessageContentType
}

enum MessageContentType {
    case text, sticker, videoMessage, image
    var prefix: String {
        switch self {
        case .text:         return ""
        case .sticker:      return "Стикер"
        case .videoMessage: return "Видеосообщение"
        case .image:        return "Фото"
        }
    }
}

struct VKMessage: Identifiable {
    let id: UUID = UUID()
    let text: String?
    let contentType: MessageContentType
    let time: String
    let isOutgoing: Bool
    let isRead: Bool
    let isDelivered: Bool
    let stickerEmoji: String?
}

// MARK: - Mock Data

extension VKChat {
    static let mockChats: [VKChat] = [
        VKChat(
            name: "Soul",
            avatarColor: Color(red: 0.55, green: 0.3, blue: 0.15),
            avatarEmoji: nil,
            lastMessage: "Стикер 🤬",
            time: "08:25",
            isPinned: true,
            isRead: true,
            isSentByMe: false,
            isDelivered: false,
            isDoubleCheck: false,
            chatType: .personal,
            unreadCount: 0,
            lastMessageType: .sticker
        ),
        VKChat(
            name: "Ванькинс🎀",
            avatarColor: .black,
            avatarEmoji: nil,
            lastMessage: "Стикер",
            time: "07:47",
            isPinned: true,
            isRead: true,
            isSentByMe: true,
            isDelivered: true,
            isDoubleCheck: true,
            chatType: .personal,
            unreadCount: 0,
            lastMessageType: .sticker
        ),
        VKChat(
            name: "Карлин",
            avatarColor: Color(red: 0.3, green: 0.2, blue: 0.5),
            avatarEmoji: nil,
            lastMessage: "уро",
            time: "пт",
            isPinned: true,
            isRead: true,
            isSentByMe: false,
            isDelivered: false,
            isDoubleCheck: false,
            chatType: .personal,
            unreadCount: 0,
            lastMessageType: .text
        ),
        VKChat(
            name: "0x766c6164696d69725f6d656d",
            avatarColor: Color(red: 0.1, green: 0.1, blue: 0.15),
            avatarEmoji: nil,
            lastMessage: "Самое смешное, что ЧТД в первые дни выглядел как проект за 3 запрос...",
            time: "вс",
            isPinned: true,
            isRead: true,
            isSentByMe: true,
            isDelivered: true,
            isDoubleCheck: true,
            chatType: .group,
            unreadCount: 0,
            lastMessageType: .text
        ),
        VKChat(
            name: "Мамочка",
            avatarColor: Color(red: 0.6, green: 0.35, blue: 0.5),
            avatarEmoji: nil,
            lastMessage: "Выпей таблетку день",
            time: "вс",
            isPinned: true,
            isRead: true,
            isSentByMe: false,
            isDelivered: false,
            isDoubleCheck: false,
            chatType: .personal,
            unreadCount: 0,
            lastMessageType: .text
        ),
        VKChat(
            name: "Ярик 🤖",
            avatarColor: Color(red: 0.2, green: 0.5, blue: 0.3),
            avatarEmoji: nil,
            lastMessage: "Это утром было я не оплатил, сейчас все есть",
            time: "08:17",
            isPinned: true,
            isRead: false,
            isSentByMe: true,
            isDelivered: true,
            isDoubleCheck: false,
            chatType: .personal,
            unreadCount: 0,
            lastMessageType: .text
        ),
        VKChat(
            name: "Саня",
            avatarColor: Color(red: 0.7, green: 0.5, blue: 0.6),
            avatarEmoji: nil,
            lastMessage: "Видеосообщение",
            time: "вс",
            isPinned: true,
            isRead: true,
            isSentByMe: false,
            isDelivered: false,
            isDoubleCheck: false,
            chatType: .personal,
            unreadCount: 0,
            lastMessageType: .videoMessage
        ),
        VKChat(
            name: "Калинкос",
            avatarColor: Color(red: 0.15, green: 0.1, blue: 0.3),
            avatarEmoji: nil,
            lastMessage: "ок",
            time: "сб",
            isPinned: false,
            isRead: true,
            isSentByMe: false,
            isDelivered: false,
            isDoubleCheck: false,
            chatType: .personal,
            unreadCount: 0,
            lastMessageType: .text
        ),
        VKChat(
            name: "Lendic",
            avatarColor: Color(red: 0.6, green: 0.15, blue: 0.15),
            avatarEmoji: nil,
            lastMessage: "хорош",
            time: "вс",
            isPinned: false,
            isRead: false,
            isSentByMe: false,
            isDelivered: false,
            isDoubleCheck: false,
            chatType: .personal,
            unreadCount: 214,
            lastMessageType: .text
        ),
    ]
}

extension VKMessage {
    static let mockVankinsMessages: [VKMessage] = [
        VKMessage(text: "Выжил", contentType: .text, time: "07:46", isOutgoing: true, isRead: true, isDelivered: true, stickerEmoji: nil),
        VKMessage(text: "Гастон, ты выжил", contentType: .text, time: "07:46", isOutgoing: false, isRead: true, isDelivered: true, stickerEmoji: nil),
        VKMessage(text: "ура", contentType: .text, time: "07:46", isOutgoing: false, isRead: true, isDelivered: true, stickerEmoji: nil),
        VKMessage(text: "ты знаешь кого я вижу", contentType: .text, time: "07:46", isOutgoing: false, isRead: true, isDelivered: true, stickerEmoji: nil),
        VKMessage(text: nil, contentType: .videoMessage, time: "07:46", isOutgoing: false, isRead: true, isDelivered: true, stickerEmoji: nil),
        VKMessage(text: "фанатка бтс", contentType: .text, time: "07:46", isOutgoing: false, isRead: true, isDelivered: true, stickerEmoji: nil),
        VKMessage(text: "моя любимая", contentType: .text, time: "07:46", isOutgoing: false, isRead: true, isDelivered: true, stickerEmoji: nil),
        VKMessage(text: nil, contentType: .image, time: "07:47", isOutgoing: true, isRead: true, isDelivered: true, stickerEmoji: nil),
    ]
}
