import SwiftUI

private let accent = Color(red: 0.35, green: 0.80, blue: 0.52)
private let bg     = Color(red: 0.10, green: 0.13, blue: 0.10)

// MARK: - Chats List

struct ChatsListView: View {
    @StateObject private var vm     = ChatsViewModel()
    @State private var search       = ""
    @State private var filter       = "Все"

    private let filters = ["Все", "Группы", "Каналы", "Личные"]

    private var shown: [VKConversationItem] {
        let base = vm.items
        let typed: [VKConversationItem]
        switch filter {
        case "Группы":  typed = base.filter { $0.conversation.peer.type == "group" }
        case "Каналы":  typed = []  // channels not in messages API by default
        case "Личные":  typed = base.filter { $0.conversation.peer.type == "user" }
        default:        typed = base
        }
        guard !search.isEmpty else { return typed }
        return typed.filter { vm.displayName(for: $0).localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    filterBar
                    Divider().background(Color(white: 0.18))
                    if vm.isLoading && vm.items.isEmpty {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        chatList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .alert("Ошибка", isPresented: .constant(vm.error != nil)) {
                Button("OK") { vm.error = nil }
            } message: { Text(vm.error ?? "") }
        }
        .task { await vm.load() }
    }

    // MARK: Search bar

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
                        Text(f == "Все" ? "⊞" : f)
                            .font(.system(size: f == "Все" ? 16 : 14, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(filter == f ? accent : Color(white: 0.15)))
                            .foregroundColor(filter == f ? Color(white: 0.06) : Color(white: 0.85))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
        }
    }

    // MARK: Chat list

    var chatList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(shown) { item in
                    NavigationLink(destination: ChatView(
                        peerId:   item.conversation.peer.id,
                        peerName: vm.displayName(for: item)
                    )) {
                        ChatRow(
                            item:     item,
                            name:     vm.displayName(for: item),
                            avatar:   vm.avatarURL(for: item),
                            preview:  vm.lastMessagePreview(item.lastMessage),
                            unread:   item.conversation.unreadCount ?? 0,
                            isPinned: item.conversation.isPinned ?? false,
                            time:     item.lastMessage?.date.vkTime ?? ""
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().background(Color(white: 0.18)).padding(.leading, 82)
                }
            }
        }
        .refreshable { await vm.refresh() }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Изм.") {}.foregroundColor(accent)
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button { } label: { Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 20)).foregroundColor(accent) }
            Button { } label: { Image(systemName: "square.and.pencil").font(.system(size: 20)).foregroundColor(accent) }
        }
    }
}

// MARK: - Chat Row

struct ChatRow: View {
    let item:     VKConversationItem
    let name:     String
    let avatar:   URL?
    let preview:  String
    let unread:   Int
    let isPinned: Bool
    let time:     String

    private let isOut = false  // determined by lastMessage.isOutgoing below

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VKAvatarView(url: avatar, name: name, size: 54)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 3) {
                        if item.lastMessage?.isOutgoing == true {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(white: 0.5))
                        }
                        Text(time).font(.system(size: 13)).foregroundColor(Color(white: 0.5))
                    }
                }
                HStack(alignment: .bottom) {
                    Text(preview)
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.5))
                        .lineLimit(2)
                    Spacer()
                    if unread > 0 {
                        Text(unread > 999 ? "999+" : "\(unread)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color(red:0.35,green:0.80,blue:0.52)))
                    } else if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.4))
                            .rotationEffect(.degrees(45))
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(bg)
    }
}

// MARK: - Reusable Avatar

struct VKAvatarView: View {
    let url:  URL?
    let name: String
    let size: CGFloat

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else { placeholder }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    var placeholder: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color(hue: nameHue, saturation: 0.55, brightness: 0.55),
                         Color(hue: nameHue, saturation: 0.70, brightness: 0.35)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private var initials: String {
        let parts = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if parts.count >= 2 { return String(parts[0].prefix(1)) + String(parts[1].prefix(1)) }
        return String(name.prefix(2)).uppercased()
    }
    private var nameHue: Double {
        let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Double(abs(hash) % 360) / 360.0
    }
}
