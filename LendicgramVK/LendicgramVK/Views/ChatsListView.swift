import SwiftUI

private let accent = Color(red: 0.35, green: 0.80, blue: 0.52)
private let bg     = Color(red: 0.10, green: 0.13, blue: 0.10)

// MARK: - Chats List

struct ChatsListView: View {
    @State private var search = ""
    @State private var filter = "Все"

    let filters = ["Все", "Группы", "Каналы", "Боты", "Личные"]
    let filterCounts: [String: Int] = ["Группы": 1, "Каналы": 10, "Боты": 15]

    var shown: [VKChat] {
        let base = VKChat.all
        switch filter {
        case "Группы":  return base.filter { $0.chatType == .group }
        case "Каналы":  return base.filter { $0.chatType == .channel }
        case "Боты":    return base.filter { $0.chatType == .bot }
        case "Личные":  return base.filter { $0.chatType == .personal }
        default:        return base
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    filterBar
                    Divider().background(Color(white: 0.18))
                    chatList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
        }
    }

    // MARK: Search

    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(Color(white: 0.45))
            TextField("", text: $search,
                      prompt: Text("Поиск").foregroundColor(Color(white: 0.35)))
                .foregroundColor(.white)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color(white: 0.4))
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 13).fill(Color(white: 0.14)))
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
    }

    // MARK: Filter chips

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { f in
                    Button { withAnimation(.easeInOut(duration: 0.15)) { filter = f } } label: {
                        HStack(spacing: 5) {
                            if f == "Все" {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(filter == f ? Color(white:0.1) : Color(white:0.55))
                            } else {
                                Text(f).font(.system(size: 14, weight: .medium))
                            }
                            if let c = filterCounts[f] {
                                Text("\(c)")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(
                                        filter == f
                                        ? Color(white:0.15).opacity(0.4)
                                        : accent))
                                    .foregroundColor(filter == f ? Color(white:0.1) : .white)
                            }
                        }
                        .padding(.horizontal, f == "Все" ? 10 : 13).padding(.vertical, 8)
                        .background(Capsule().fill(filter == f ? accent : Color(white: 0.15)))
                        .foregroundColor(filter == f ? Color(white:0.08) : Color(white:0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
        }
    }

    // MARK: Chat list

    var chatList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(shown) { chat in
                    NavigationLink(destination: ChatView(chat: chat)) {
                        ChatRow(chat: chat)
                    }
                    .buttonStyle(.plain)
                    Divider().background(Color(white: 0.18)).padding(.leading, 82)
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Изм.") {}.foregroundColor(accent)
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button { } label: { Image(systemName: "power.circle").font(.system(size: 20)).foregroundColor(accent) }
            Button { } label: { Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 20)).foregroundColor(accent) }
            Button { } label: { Image(systemName: "square.and.pencil").font(.system(size: 20)).foregroundColor(accent) }
            Circle()
                .fill(Color(red:0.55,green:0.28,blue:0.12))
                .frame(width: 32, height: 32)
                .overlay(Text("L").font(.system(size: 14, weight: .bold)).foregroundColor(.white))
        }
    }
}

// MARK: - Chat Row

struct ChatRow: View {
    let chat: VKChat
    private let accent = Color(red: 0.35, green: 0.80, blue: 0.52)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(chat.avatarColor)
                .frame(width: 54, height: 54)
                .overlay(
                    Text(initials(chat.name))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                // Name + time row
                HStack {
                    Text(chat.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 3) {
                        if chat.isSentByMe {
                            Image(systemName: chat.isDoubleCheck ? "checkmark.circle.fill" : "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(white: 0.5))
                        }
                        Text(chat.time)
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.5))
                    }
                }

                // Last message + badge/pin
                HStack(alignment: .bottom) {
                    lastMessageView
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.5))
                        .lineLimit(2)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(accent))
                    } else if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.4))
                            .rotationEffect(.degrees(45))
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(red: 0.10, green: 0.13, blue: 0.10))
    }

    @ViewBuilder var lastMessageView: some View {
        switch chat.lastMsgType {
        case .sticker:
            HStack(spacing: 4) {
                Text("Стикер")
                if chat.lastMessage.contains(" ") {
                    Text(chat.lastMessage.components(separatedBy: " ").last ?? "")
                }
            }
        case .videoNote:
            HStack(spacing: 5) {
                Image(systemName: "play.circle.fill").font(.system(size: 14))
                Text("Видеосообщение")
            }
        case .photo:
            HStack(spacing: 5) {
                Image(systemName: "photo").font(.system(size: 14))
                Text("Фотография")
            }
        default:
            Text(chat.lastMessage)
        }
    }

    func initials(_ name: String) -> String {
        let parts = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if parts.count >= 2 { return String(parts[0].prefix(1)) + String(parts[1].prefix(1)) }
        return String(name.prefix(2)).uppercased()
    }
}
