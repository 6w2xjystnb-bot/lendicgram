import SwiftUI

struct ContactsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red:0.10,green:0.13,blue:0.10).ignoresSafeArea()
                VStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(white: 0.25))
                    Text("Контакты").font(.system(size: 20)).foregroundColor(Color(white: 0.35))
                }
            }
            .navigationTitle("Контакты")
            .toolbarBackground(Color(red:0.10,green:0.13,blue:0.10), for:.navigationBar)
            .toolbarBackground(.visible, for:.navigationBar)
        }
    }
}
