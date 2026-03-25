import SwiftUI

struct ProfileView: View {
    @StateObject private var vm   = ProfileViewModel()
    @ObservedObject private var auth = VKAuthService.shared

    var body: some View {
        NavigationStack {
            List {
                // Header section
                Section {
                    HStack(spacing: 14) {
                        VKAvatarView(
                            url: vm.user?.avatarURL,
                            name: vm.user?.fullName ?? "...",
                            size: 62
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            if let user = vm.user {
                                Text(user.fullName)
                                    .font(.system(size: 18, weight: .semibold))
                                Text("ВКонтакте")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(.secondaryLabel))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemFill))
                                    .frame(width: 140, height: 18)
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(.systemFill))
                                    .frame(width: 80, height: 13)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // Settings
                Section {
                    settingsRow(icon: "bell.fill",
                                iconBg: Color.red,
                                title: "Уведомления")
                    settingsRow(icon: "lock.fill",
                                iconBg: Color(red: 0.40, green: 0.58, blue: 0.94),
                                title: "Конфиденциальность")
                    settingsRow(icon: "paintbrush.fill",
                                iconBg: Color(red: 0.60, green: 0.30, blue: 0.90),
                                title: "Оформление")
                    settingsRow(icon: "folder.fill",
                                iconBg: Color(red: 0.48, green: 0.68, blue: 0.32),
                                title: "Папки с чатами")
                    settingsRow(icon: "arrow.triangle.2.circlepath",
                                iconBg: Color(red: 0.22, green: 0.72, blue: 0.40),
                                title: "Прокси",
                                value: "Откл.")
                }

                Section {
                    settingsRow(icon: "questionmark.circle.fill",
                                iconBg: Color(red: 0.24, green: 0.62, blue: 0.90),
                                title: "Помощь")
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        auth.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Выйти из аккаунта")
                                .font(.system(size: 16))
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(graphiteBg.ignoresSafeArea())
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
        }
        .tint(tgAccent)
        .task { await vm.load() }
    }

    @ViewBuilder
    func settingsRow(icon: String, iconBg: Color, title: String, value: String? = nil) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 9)
                .fill(iconBg)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                )
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color(.label))
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }
}
