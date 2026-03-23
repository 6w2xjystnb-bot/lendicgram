import SwiftUI

struct ChatsListView: View {
    @State private var searchText = ""
    @State private var selectedFilter = "Все"
    @State private var selectedChat: VKChat? = nil

    let filterChips: [FilterChip] = [
        FilterChip(title: "Все", count: nil),
        FilterChip(title: "Группы", count: 1),
        FilterChip(title: "Каналы", count: 10),
        FilterChip(title: "Боты", count: 15),
        FilterChip(title: "Личные", count: nil),
    ]

    var filteredChats: [VKChat] {
        let base = VKChat.mockChats
        switch selectedFilter {
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
                Color(red: 0.1, green: 0.13, blue: 0.1)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(white: 0.5))
                        TextField("", text: $searchText,
                                  prompt: Text("Поиск")
                                    .foregroundColor(Color(white: 0.4)))
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(white: 0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.13))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    // Filter chips
                    FilterChipsView(selected: $selectedFilter, chips: filterChips)

                    Divider()
                        .background(Color(white: 0.18))

                    // Chats list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredChats) { chat in
                                NavigationLink(destination: ChatDetailView(chat: chat)) {
                                    ChatRowView(chat: chat)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .background(Color(white: 0.18))
                                    .padding(.leading, 82)
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Изм.") {}
                        .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.5))
                        .font(.system(size: 16))
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { } label: {
                        Image(systemName: "power.circle")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.5))
                    }
                    Button { } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.5))
                    }
                    Button { } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.5))
                    }
                    Circle()
                        .fill(Color(red: 0.55, green: 0.3, blue: 0.15))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("L")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            }
            .toolbarBackground(Color(red: 0.1, green: 0.13, blue: 0.1), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
