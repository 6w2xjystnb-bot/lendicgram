import SwiftUI

struct ContentView: View {
    @ObservedObject private var auth = VKAuthService.shared
    @State private var selectedTab = 1

    var body: some View {
        if auth.isAuthenticated {
            mainTabs
        } else {
            AuthView()
        }
    }

    var mainTabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Контакты", systemImage: "person.2", value: 0) {
                ContactsView()
            }
            Tab("Чаты", systemImage: "message", value: 1) {
                ChatsListView()
            }
            Tab("Настройки", systemImage: "gearshape", value: 2) {
                ProfileView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.35, green: 0.80, blue: 0.52))
    }
}
