import SwiftUI
import Combine

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var friends: [VKUser] = []
    @Published var isLoading = false
    @Published var error: String?

    private let api      = VKAPIService.shared
    private let longPoll = VKLongPollService.shared
    private var bag      = Set<AnyCancellable>()

    init() {
        longPoll.$onlineEvent
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self,
                      let idx = self.friends.firstIndex(where: { $0.id == event.userId })
                else { return }
                // Refresh friend's status
                Task { await self.refreshUser(at: idx) }
            }
            .store(in: &bag)
    }

    func load() async {
        isLoading = true
        do {
            let r = try await api.getFriends()
            friends = r.items
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func refresh() async {
        do {
            let r = try await api.getFriends()
            friends = r.items
        } catch {}
    }

    private func refreshUser(at index: Int) async {
        let userId = friends[index].id
        do {
            let users = try await api.getUsers([userId])
            if let u = users.first, index < friends.count, friends[index].id == u.id {
                friends[index] = u
            }
        } catch {}
    }

    var onlineFriends: [VKUser] { friends.filter { $0.isOnline } }
    var offlineFriends: [VKUser] { friends.filter { !$0.isOnline } }
}
