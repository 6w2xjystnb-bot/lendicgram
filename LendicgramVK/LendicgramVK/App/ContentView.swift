import SwiftUI

struct ContentView: View {
    var body: some View {
        // iOS 26: нативный TabView = автоматический Liquid Glass
        TabView {
            Tab("Контакты", systemImage: "person.2") {
                ContactsView()
            }

            Tab("Чаты", systemImage: "message") {
                ChatsListView()
            }
            .badge(17)

            Tab("Настройки", systemImage: "gearshape") {
                ProfileView()
            }
            .badge(214)
        }
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.35, green: 0.80, blue: 0.52))
    }
}
