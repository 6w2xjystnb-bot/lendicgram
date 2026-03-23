import SwiftUI

struct ContentView: View {
    @ObservedObject private var auth = VKAuthService.shared

    var body: some View {
        if auth.isAuthenticated {
            mainTabs
        } else {
            AuthView()
        }
    }

    var mainTabs: some View {
        TabView {
            Tab("Контакты", systemImage: "person.2") {
                ContactsView()
            }
            Tab("Чаты", systemImage: "message") {
                ChatsListView()
            }
            Tab("Настройки", systemImage: "gearshape") {
                ProfileView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.35, green: 0.80, blue: 0.52))
    }
}
