import SwiftUI

private let accent = Color(red: 0.35, green: 0.80, blue: 0.52)
private let bg     = Color(red: 0.10, green: 0.13, blue: 0.10)

struct ContactsView: View {
    @StateObject private var vm = ContactsViewModel()
    @State private var search = ""

    private var filtered: [VKUser] {
        guard !search.isEmpty else { return vm.friends }
        return vm.friends.filter { $0.fullName.localizedCaseInsensitiveContains(search) }
    }

    private var onlineCount: Int { vm.onlineFriends.count }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    Divider().background(Color(white: 0.18))

                    if vm.isLoading && vm.friends.isEmpty {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        friendsList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Контакты")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task { await vm.load() }
    }

    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(Color(white: 0.45))
            TextField("", text: $search,
                      prompt: Text("Поиск друзей").foregroundColor(Color(white: 0.35)))
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

    var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if search.isEmpty && onlineCount > 0 {
                    sectionHeader("В сети — \(onlineCount)")
                    ForEach(vm.onlineFriends) { user in
                        friendRow(user)
                        Divider().background(Color(white: 0.18)).padding(.leading, 76)
                    }
                    sectionHeader("Все друзья — \(vm.friends.count)")
                    ForEach(vm.offlineFriends) { user in
                        friendRow(user)
                        Divider().background(Color(white: 0.18)).padding(.leading, 76)
                    }
                } else {
                    ForEach(filtered) { user in
                        friendRow(user)
                        Divider().background(Color(white: 0.18)).padding(.leading, 76)
                    }
                }
            }
        }
        .refreshable { await vm.refresh() }
    }

    func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(white: 0.5))
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(bg.opacity(0.8))
    }

    func friendRow(_ user: VKUser) -> some View {
        NavigationLink(destination: ChatView(peerId: user.id, peerName: user.fullName)) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    VKAvatarView(url: user.avatarURL, name: user.fullName, size: 48)
                    if user.isOnline {
                        Circle()
                            .fill(accent)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(bg, lineWidth: 2))
                            .offset(x: 1, y: 1)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(user.statusText)
                        .font(.system(size: 13))
                        .foregroundColor(user.isOnline ? accent : Color(white: 0.45))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
