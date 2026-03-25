import SwiftUI

// Telegram-inspired blue accent used across all screens
let tgAccent = Color(red: 0.00, green: 0.66, blue: 0.52) // #00a884 Whitegram green

struct ChatDestination: Hashable {
    let peerId: Int
    let peerName: String
}

// MARK: - Chats List

struct ChatsListView: View {
    @StateObject private var vm     = ChatsViewModel()
    @State private var search       = ""
    @State private var filter       = "Все"
    @State private var path         = NavigationPath()

    private let filters = ["Все", "Личные", "Группы"]

    private var shown: [VKConversationItem] {
        let base: [VKConversationItem]
        switch filter {
        case "Личные":  base = vm.items.filter { $0.conversation.peer.type == "user" }
        case "Группы":  base = vm.items.filter { $0.conversation.peer.type != "user" }
        default:        base = vm.items
        }
        guard !search.isEmpty else { return base }
        return base.filter { vm.displayName(for: $0).localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                filterBar
                Divider().opacity(0.4)

                if vm.isLoading && vm.items.isEmpty {
                    Spacer()
                    ProgressView().tint(tgAccent)
                    Spacer()
                } else {
                    chatList
                }
            }
            .navigationTitle("Сообщения")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Поиск")
            .toolbar { toolbarItems }
            .navigationDestination(for: ChatDestination.self) { dest in
                ChatView(peerId: dest.peerId, peerName: dest.peerName)
            }
            .alert("Ошибка", isPresented: .constant(vm.error != nil)) {
                Button("OK") { vm.error = nil }
            } message: { Text(vm.error ?? "") }
        }
        .toolbarVisibility(path.isEmpty ? .automatic : .hidden, for: .tabBar)
        .animation(.easeInOut(duration: 0.25), value: path.isEmpty)
        .tint(tgAccent)
        .task { await vm.load() }
        .onChange(of: path.isEmpty) { _, isEmpty in
            if isEmpty { Task { await vm.refresh() } }
        }
    }

    // MARK: - Filter chips

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { f in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { filter = f }
                    } label: {
                        Text(f)
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .foregroundStyle(filter == f ? Color.white : Color(.label))
                            .background {
                                if filter == f {
                                    Capsule().fill(tgAccent)
                                } else {
                                    Capsule().fill(.clear).glassEffect(.regular.interactive(), in: .capsule)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    // MARK: - Chat list

    var chatList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(shown) { item in
                    NavigationLink(value: ChatDestination(
                        peerId:   item.conversation.peer.id,
                        peerName: vm.displayName(for: item)
                    )) {
                        ChatRow(
                            item:     item,
                            name:     vm.displayName(for: item),
                            avatar:   vm.avatarURL(for: item),
                            preview:  vm.isTyping(for: item) ?? vm.lastMessagePreview(item.lastMessage),
                            isTyping: vm.isTyping(for: item) != nil,
                            unread:   item.conversation.unreadCount ?? 0,
                            isPinned: item.conversation.isPinned ?? false,
                            time:     item.lastMessage?.date.vkTime ?? "",
                            isOnline: vm.isOnline(for: item),
                            isMobile: vm.isMobileOnline(for: item),
                            delivery: vm.deliveryStatus(for: item)
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 82)
                }
            }
        }
        .refreshable { await vm.refresh() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
            }
        }
    }
}

// MARK: - Chat Row

struct ChatRow: View {
    let item:     VKConversationItem
    let name:     String
    let avatar:   URL?
    let preview:  String
    let isTyping: Bool
    let unread:   Int
    let isPinned: Bool
    let time:     String
    let isOnline: Bool
    let isMobile: Bool
    let delivery: ChatsViewModel.DeliveryStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                VKAvatarView(url: avatar, name: name, size: 54)
                if isOnline {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle().fill(tgAccent).padding(2.5)
                        )
                        .offset(x: 1, y: 1)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 3) {
                        // Delivery check
                        switch delivery {
                        case .read:
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(tgAccent)
                        case .sent:
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        case .none:
                            EmptyView()
                        }
                        Text(time)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }

                HStack(alignment: .bottom) {
                    Text(preview)
                        .font(.system(size: 14))
                        .foregroundStyle(isTyping ? tgAccent : Color(.secondaryLabel))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if unread > 0 {
                        Text(unread > 999 ? "999+" : "\(unread)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(tgAccent))
                    } else if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .rotationEffect(.degrees(45))
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
