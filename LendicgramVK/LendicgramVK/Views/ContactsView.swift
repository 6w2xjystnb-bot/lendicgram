import SwiftUI

struct ContactsView: View {
    @StateObject private var vm = ContactsViewModel()
    @State private var search = ""
    @State private var path   = NavigationPath()

    private var filtered: [VKUser] {
        guard !search.isEmpty else { return vm.friends }
        return vm.friends.filter { $0.fullName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if vm.isLoading && vm.friends.isEmpty {
                    HStack { Spacer(); ProgressView().tint(tgAccent); Spacer() }
                        .listRowBackground(Color.clear)
                } else if search.isEmpty && !vm.onlineFriends.isEmpty {
                    Section("В сети — \(vm.onlineFriends.count)") {
                        ForEach(vm.onlineFriends) { user in
                            friendRow(user)
                        }
                    }
                    Section("Все друзья — \(vm.friends.count)") {
                        ForEach(vm.offlineFriends) { user in
                            friendRow(user)
                        }
                    }
                } else {
                    ForEach(filtered) { user in
                        friendRow(user)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await vm.refresh() }
            .navigationTitle("Контакты")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $search, prompt: "Поиск друзей")
            .navigationDestination(for: ChatDestination.self) { dest in
                ChatView(peerId: dest.peerId, peerName: dest.peerName)
            }
        }
        .toolbarVisibility(path.isEmpty ? .automatic : .hidden, for: .tabBar)
        .animation(.easeInOut(duration: 0.25), value: path.isEmpty)
        .tint(tgAccent)
        .task { await vm.load() }
    }

    @ViewBuilder
    func friendRow(_ user: VKUser) -> some View {
        NavigationLink(value: ChatDestination(peerId: user.id, peerName: user.fullName)) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    VKAvatarView(url: user.avatarURL, name: user.fullName, size: 46)
                    if user.isOnline {
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 14, height: 14)
                            .overlay(Circle().fill(tgOnline).padding(2.5))
                            .offset(x: 1, y: 1)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    Text(user.statusText)
                        .font(.system(size: 13))
                        .foregroundStyle(user.isOnline ? tgOnline : Color(.secondaryLabel))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
