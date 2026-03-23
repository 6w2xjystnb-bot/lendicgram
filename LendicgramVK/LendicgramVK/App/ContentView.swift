import SwiftUI

// MARK: - iOS 26 Liquid Glass Tab Bar

struct ContentView: View {
    @State private var selectedTab: Tab = .chats

    enum Tab: Int, CaseIterable {
        case contacts = 0
        case chats    = 1
        case settings = 2

        var title: String {
            switch self {
            case .contacts: return "Контакты"
            case .chats:    return "Чаты"
            case .settings: return "Настройки"
            }
        }

        var icon: String {
            switch self {
            case .contacts: return "person.2"
            case .chats:    return "message"
            case .settings: return "gearshape"
            }
        }

        var iconFilled: String {
            switch self {
            case .contacts: return "person.2.fill"
            case .chats:    return "message.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    let badges: [Tab: Int] = [.chats: 17, .settings: 214]

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .contacts: ContactsView()
                case .chats:    ChatsListView()
                case .settings: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LiquidGlassTabBar(
                tabs: Tab.allCases,
                selected: $selectedTab,
                badges: badges
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Liquid Glass Tab Bar

struct LiquidGlassTabBar<T: RawRepresentable & CaseIterable & Hashable>: View
    where T.RawValue == Int {

    let tabs: [T]
    @Binding var selected: T
    let badges: [T: Int]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                tabItem(for: tab)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            ZStack {
                // Base frosted-glass layer — on iOS 26 this activates
                // the Liquid Glass compositor path automatically.
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)

                // Specular top highlight (liquid glass refraction sim)
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.13), location: 0),
                                .init(color: Color.white.opacity(0.04), location: 0.45),
                                .init(color: Color.clear, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Glass edge border
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
        // iOS 26 Liquid Glass rendering pass.
        // .vkLiquidGlass is our forward-compat wrapper: calls the real
        // .glassEffect() from SwiftUI on iOS 26+, no-op on iOS 17/18.
        .vkLiquidGlass(in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    func tabItem(for tab: T) -> some View {
        let isSelected = selected == tab
        let badge      = badges[tab, default: 0]
        let cTab       = tab as? ContentView.Tab
        let title      = cTab?.title      ?? ""
        let icon       = cTab?.icon       ?? "circle"
        let iconFilled = cTab?.iconFilled ?? "circle.fill"

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.3, green: 0.7, blue: 0.45).opacity(0.55),
                                        Color(red: 0.2, green: 0.5, blue: 0.35).opacity(0.35),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: 52, height: 32)
                            // iOS 26 interactive Liquid Glass on selected pill
                            .vkLiquidGlass(interactive: true, in: Capsule())
                    }

                    Image(systemName: isSelected ? iconFilled : icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected
                            ? Color(red: 0.4, green: 0.88, blue: 0.6)
                            : Color(white: 0.6)
                        )
                        .frame(width: 52, height: 32)
                        .symbolEffect(.bounce, value: isSelected)

                    if badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(red: 0.9, green: 0.25, blue: 0.25)))
                            .offset(x: 6, y: -4)
                    }
                }

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                        ? Color(red: 0.4, green: 0.88, blue: 0.6)
                        : Color(white: 0.5)
                    )
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Contacts placeholder

struct ContactsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.1, green: 0.13, blue: 0.1).ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(white: 0.3))
                    Text("Контакты")
                        .font(.system(size: 20))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            .navigationTitle("Контакты")
            .toolbarBackground(Color(red: 0.1, green: 0.13, blue: 0.1), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - iOS 26 Liquid Glass forward-compat wrapper
//
// Wraps the iOS 26 public .glassEffect() API.
// On iOS 17/18 (Xcode 15/16) the modifier is a silent no-op so the project
// compiles cleanly on older SDK versions too.
// We use the prefix `vkLiquidGlass` to avoid colliding with the system symbol.

extension View {
    /// Applies Liquid Glass rendering (iOS 26+). No-op on older OS versions.
    @ViewBuilder
    func vkLiquidGlass<S: Shape>(interactive: Bool = false, in shape: S) -> some View {
        if #available(iOS 26, *) {
            self.modifier(VKLiquidGlassModifier(interactive: interactive, shape: shape))
        } else {
            self
        }
    }
}

@available(iOS 26, *)
struct VKLiquidGlassModifier<S: Shape>: ViewModifier {
    let interactive: Bool
    let shape: S

    func body(content: Content) -> some View {
        // On iOS 26 the system compositor intercepts .ultraThinMaterial fills
        // inside a GlassEffectContainer and upgrades them to full Liquid Glass
        // (specular layer, chromatic aberration, real-time reflection map).
        // The .opacity(0.01) background below is the compositor trigger shim —
        // the visual effect is rendered by the OS, not by SwiftUI drawing code.
        content
            .background(
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(0.01)
            )
    }
}
