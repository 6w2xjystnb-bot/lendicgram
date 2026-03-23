import SwiftUI

// MARK: - Models

enum ChatType { case personal, group, channel, bot }

enum LastMsgType {
    case text, sticker, videoNote, photo
    var prefix: String {
        switch self {
        case .text:      return ""
        case .sticker:   return "Стикер"
        case .videoNote: return "Видеосообщение"
        case .photo:     return "Фотография"
        }
    }
}

struct VKChat: Identifiable {
    let id = UUID()
    let name: String
    let avatarColor: Color
    let lastMessage: String
    let time: String
    let isPinned: Bool
    let isSentByMe: Bool
    let isRead: Bool
    let isDoubleCheck: Bool
    let chatType: ChatType
    let unreadCount: Int
    let lastMsgType: LastMsgType
}

struct VKMessage: Identifiable {
    let id = UUID()
    let text: String?
    let type: LastMsgType
    let time: String
    let isOutgoing: Bool
    let isRead: Bool
}

// MARK: - Mock

extension VKChat {
    static let all: [VKChat] = [
        VKChat(name:"Soul",          avatarColor:Color(red:0.55,green:0.28,blue:0.12), lastMessage:"Стикер 🤬",  time:"08:25", isPinned:true, isSentByMe:false, isRead:true,  isDoubleCheck:false, chatType:.personal, unreadCount:0,   lastMsgType:.sticker),
        VKChat(name:"Ванькинс🎀",    avatarColor:.black,                               lastMessage:"Стикер",      time:"07:47", isPinned:true, isSentByMe:true,  isRead:true,  isDoubleCheck:true,  chatType:.personal, unreadCount:0,   lastMsgType:.sticker),
        VKChat(name:"Карлин",        avatarColor:Color(red:0.28,green:0.18,blue:0.50), lastMessage:"уро",         time:"пт",    isPinned:true, isSentByMe:false, isRead:true,  isDoubleCheck:false, chatType:.personal, unreadCount:0,   lastMsgType:.text),
        VKChat(name:"0x766c6164696d69725f6d656d", avatarColor:Color(red:0.10,green:0.10,blue:0.14), lastMessage:"Самое смешное, что ЧТД в первые дни выглядел как проект за 3 запрос...", time:"вс", isPinned:true, isSentByMe:true, isRead:true, isDoubleCheck:true, chatType:.group, unreadCount:0, lastMsgType:.text),
        VKChat(name:"Мамочка",       avatarColor:Color(red:0.55,green:0.30,blue:0.48), lastMessage:"Выпей таблетку день", time:"вс", isPinned:true, isSentByMe:false, isRead:true, isDoubleCheck:false, chatType:.personal, unreadCount:0, lastMsgType:.text),
        VKChat(name:"Ярик 🤖",       avatarColor:Color(red:0.18,green:0.48,blue:0.28), lastMessage:"Это утром было я не оплатил, сейчас все есть", time:"08:17", isPinned:true, isSentByMe:true, isRead:false, isDoubleCheck:false, chatType:.personal, unreadCount:0, lastMsgType:.text),
        VKChat(name:"Саня",          avatarColor:Color(red:0.68,green:0.45,blue:0.58), lastMessage:"Видеосообщение", time:"вс", isPinned:true, isSentByMe:false, isRead:true, isDoubleCheck:false, chatType:.personal, unreadCount:0, lastMsgType:.videoNote),
        VKChat(name:"Калинкос",      avatarColor:Color(red:0.14,green:0.10,blue:0.28), lastMessage:"ок",          time:"сб",    isPinned:false, isSentByMe:false, isRead:true,  isDoubleCheck:false, chatType:.personal, unreadCount:0,   lastMsgType:.text),
        VKChat(name:"Lendic",        avatarColor:Color(red:0.55,green:0.12,blue:0.12), lastMessage:"хорош",       time:"вс",    isPinned:false, isSentByMe:false, isRead:false, isDoubleCheck:false, chatType:.personal, unreadCount:214, lastMsgType:.text),
    ]
}

extension VKMessage {
    static let vankinsChat: [VKMessage] = [
        VKMessage(text:"Выжил",                   type:.text,      time:"07:46", isOutgoing:true,  isRead:true),
        VKMessage(text:"Гастон, ты выжил",        type:.text,      time:"07:46", isOutgoing:false, isRead:true),
        VKMessage(text:"ура",                     type:.text,      time:"07:46", isOutgoing:false, isRead:true),
        VKMessage(text:"ты знаешь кого я вижу",  type:.text,      time:"07:46", isOutgoing:false, isRead:true),
        VKMessage(text:nil,                       type:.videoNote, time:"07:46", isOutgoing:false, isRead:true),
        VKMessage(text:"фанатка бтс",             type:.text,      time:"07:46", isOutgoing:false, isRead:true),
        VKMessage(text:"моя любимая",             type:.text,      time:"07:46", isOutgoing:false, isRead:true),
        VKMessage(text:nil,                       type:.photo,     time:"07:47", isOutgoing:true,  isRead:true),
    ]
}
