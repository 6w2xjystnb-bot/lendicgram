import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.1, green: 0.13, blue: 0.1)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Avatar + name section
                        VStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.35, green: 0.6, blue: 0.45),
                                                Color(red: 0.2, green: 0.4, blue: 0.3),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        // White owl/seagull placeholder
                                        Text("🦆")
                                            .font(.system(size: 55))
                                    )

                                Circle()
                                    .fill(Color(red: 0.12, green: 0.15, blue: 0.12))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(white: 0.7))
                                    )
                                    .offset(x: -5, y: 5)
                            }

                            VStack(spacing: 3) {
                                Text("Иван")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                                Text("@lendic42")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(white: 0.55))
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 20)

                        // Change photo button
                        settingsRow(
                            icon: "camera",
                            iconColor: Color(red: 0.35, green: 0.75, blue: 0.5),
                            title: "Изменить фотографию",
                            showChevron: false
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        // Accounts section
                        VStack(spacing: 0) {
                            accountRow(
                                avatarEmoji: "🐺",
                                avatarColor: Color(red: 0.55, green: 0.25, blue: 0.25),
                                name: "Lendic",
                                badge: 214
                            )
                            Divider().background(Color(white: 0.18))
                                .padding(.leading, 62)
                            addAccountRow()
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12)))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                        // Settings rows
                        VStack(spacing: 0) {
                            settingsRow(
                                icon: "person.fill",
                                iconColor: Color(red: 0.85, green: 0.25, blue: 0.25),
                                title: "Мой профиль"
                            )
                            Divider().background(Color(white: 0.18)).padding(.leading, 56)

                            settingsRow(
                                icon: "sparkles",
                                iconColor: Color(red: 0.55, green: 0.55, blue: 0.65),
                                title: "Whitegram"
                            )
                            Divider().background(Color(white: 0.18)).padding(.leading, 56)

                            settingsRow(
                                icon: "arrow.triangle.2.circlepath",
                                iconColor: Color(red: 0.25, green: 0.75, blue: 0.4),
                                title: "Прокси",
                                value: "Отключён"
                            )
                            Divider().background(Color(white: 0.18)).padding(.leading, 56)

                            settingsRow(
                                icon: "creditcard.fill",
                                iconColor: Color(red: 0.2, green: 0.45, blue: 0.85),
                                title: "Кошелёк"
                            )
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12)))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                        // More settings
                        VStack(spacing: 0) {
                            settingsRow(icon: "bell.fill", iconColor: Color(red: 0.9, green: 0.5, blue: 0.15), title: "Уведомления")
                            Divider().background(Color(white: 0.18)).padding(.leading, 56)
                            settingsRow(icon: "lock.fill", iconColor: Color(red: 0.4, green: 0.6, blue: 0.9), title: "Конфиденциальность")
                            Divider().background(Color(white: 0.18)).padding(.leading, 56)
                            settingsRow(icon: "paintbrush.fill", iconColor: Color(red: 0.6, green: 0.35, blue: 0.9), title: "Оформление")
                            Divider().background(Color(white: 0.18)).padding(.leading, 56)
                            settingsRow(icon: "folder.fill", iconColor: Color(red: 0.5, green: 0.7, blue: 0.35), title: "Папки с чатами")
                            Divider().background(Color(white: 0.18)).padding(.leading, 56)
                            settingsRow(icon: "network", iconColor: Color(red: 0.35, green: 0.65, blue: 0.85), title: "Использование данных")
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12)))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Изм.") {}
                        .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.5))
                }
            }
            .toolbarBackground(Color(red: 0.1, green: 0.13, blue: 0.1), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    @ViewBuilder
    func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String? = nil,
        showChevron: Bool = true
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)

            Spacer()

            if let val = value {
                Text(val)
                    .font(.system(size: 15))
                    .foregroundColor(Color(white: 0.45))
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(white: 0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    func accountRow(avatarEmoji: String, avatarColor: Color, name: String, badge: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 38, height: 38)
                Text(avatarEmoji)
                    .font(.system(size: 22))
            }

            Text(name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Text("\(badge)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(red: 0.25, green: 0.55, blue: 0.35)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    func addAccountRow() -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(red: 0.35, green: 0.75, blue: 0.5), lineWidth: 2)
                    .frame(width: 38, height: 38)
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.5))
            }

            Text("Добавить аккаунт")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.5))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
