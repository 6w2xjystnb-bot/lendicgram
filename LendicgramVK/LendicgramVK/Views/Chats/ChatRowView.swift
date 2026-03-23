import SwiftUI

struct ChatRowView: View {
    let chat: VKChat

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(name: chat.name, color: chat.avatarColor, size: 54)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(chat.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 4) {
                        if chat.isSentByMe {
                            Image(systemName: chat.isDoubleCheck ? "checkmark.circle.fill" : "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(white: 0.55))
                        }
                        Text(chat.time)
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.5))
                    }
                }

                HStack(alignment: .bottom) {
                    Group {
                        if chat.lastMessageType == .sticker {
                            HStack(spacing: 4) {
                                Text("Стикер")
                                    .foregroundColor(Color(white: 0.5))
                                if let emoji = chat.lastMessage.components(separatedBy: " ").last,
                                   emoji != "Стикер" {
                                    Text(emoji)
                                }
                            }
                        } else if chat.lastMessageType == .videoMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(white: 0.5))
                                Text("Видеосообщение")
                                    .foregroundColor(Color(white: 0.5))
                            }
                        } else {
                            Text(chat.lastMessage)
                                .foregroundColor(Color(white: 0.5))
                                .lineLimit(2)
                        }
                    }
                    .font(.system(size: 14))

                    Spacer()

                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(red: 0.25, green: 0.55, blue: 0.35)))
                    } else if chat.isPinned {
                        PinnedIndicator()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.1, green: 0.13, blue: 0.1))
    }
}
