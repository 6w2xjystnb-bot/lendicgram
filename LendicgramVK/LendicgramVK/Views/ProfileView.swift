import SwiftUI

private let accent = Color(red: 0.35, green: 0.80, blue: 0.52)
private let bg     = Color(red: 0.10, green: 0.13, blue: 0.10)

struct ProfileView: View {
    @StateObject private var vm   = ProfileViewModel()
    @ObservedObject private var auth = VKAuthService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        card {
                            row(icon: "person.fill",   color: Color(red:0.85,green:0.22,blue:0.22), title: "Мой профиль")
                            sep
                            row(icon: "bell.fill",     color: Color(red:0.90,green:0.48,blue:0.14), title: "Уведомления")
                            sep
                            row(icon: "lock.fill",     color: Color(red:0.38,green:0.58,blue:0.90), title: "Конфиденциальность")
                            sep
                            row(icon: "paintbrush.fill", color: Color(red:0.58,green:0.32,blue:0.90), title: "Оформление")
                            sep
                            row(icon: "folder.fill",   color: Color(red:0.48,green:0.68,blue:0.32), title: "Папки с чатами")
                            sep
                            row(icon: "arrow.triangle.2.circlepath", color: Color(red:0.22,green:0.72,blue:0.40), title: "Прокси", value: "Откл.")
                        }
                        .padding(.horizontal, 16).padding(.bottom, 10)

                        card {
                            Button {
                                auth.logout()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Выйти из аккаунта")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task { await vm.load() }
    }

    // MARK: Header

    var header: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                VKAvatarView(
                    url: vm.user?.avatarURL,
                    name: vm.user?.fullName ?? "...",
                    size: 90
                )
                Circle()
                    .fill(bg)
                    .frame(width: 28, height: 28)
                    .overlay(Image(systemName: "qrcode").font(.system(size: 12)).foregroundColor(Color(white: 0.65)))
                    .offset(x: -2, y: 2)
            }
            VStack(spacing: 3) {
                if let user = vm.user {
                    Text(user.fullName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Circle().fill(accent).frame(width: 8, height: 8)
                        Text("в сети").font(.system(size: 14)).foregroundColor(Color(white: 0.5))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(white: 0.18))
                        .frame(width: 160, height: 22)
                }
            }
        }
        .padding(.top, 20).padding(.bottom, 20)
    }

    // MARK: Helpers

    @ViewBuilder
    func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12)))
    }

    @ViewBuilder
    func row(icon: String, color: Color, title: String, value: String? = nil) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8).fill(color).frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(.white))
            Text(title).font(.system(size: 16)).foregroundColor(.white)
            Spacer()
            if let v = value { Text(v).font(.system(size: 14)).foregroundColor(Color(white: 0.4)) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(white: 0.28))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    var sep: some View {
        Divider().background(Color(white: 0.18)).padding(.leading, 56)
    }
}
