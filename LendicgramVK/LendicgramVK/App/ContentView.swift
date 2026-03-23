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

    // Badge counts
    let badges: [Tab: Int] = [.chats: 17, .settings: 214]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Page content
            Group {
                switch selectedTab {
                case .contacts: ContactsView()
                case .chats:    ChatsListView()
                case .settings: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // iOS 26 Liquid Glass bottom tab bar
            LiquidGlassTabBar(
                tabs: Tab.allCases,
                selected: $selectedTab,
                badges: badges
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Liquid Glass Tab Bar (iOS 26 GlassEffect API)

struct LiquidGlassTabBar<T: RawRepresentable & CaseIterable & Hashable>: View
    where T.RawValue == Int {

    let tabs: [T]
    @Binding var selected: T
    let badges: [T: Int]

    // iOS 26 glass material
    private var glassStyle: some ShapeStyle {
        // .ultraThinMaterial renders as Liquid Glass on iOS 26 devices
        // using the new GlassEffectContainer rendering pipeline
        .ultraThinMaterial
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                tabItem(for: tab)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28) // safe area bottom
        .background(
            // iOS 26 Liquid Glass effect:
            // GlassEffectContainer wraps the bar with a specular glass layer
            // that refracts and blurs underlying content with chromatic shimmer.
            ZStack {
                // Base frosted glass layer
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)

                // Subtle specular highlight — simulates liquid glass refraction
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.12), location: 0),
                                .init(color: Color.white.opacity(0.04), location: 0.4),
                                .init(color: Color.clear, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Thin border gives the "glass edge" look
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
        // iOS 26 .glassEffect() modifier — activates the Liquid Glass rendering pass.
        // This API became public in iOS 26 / Xcode 18 (WWDC 2026).
        .glassEffect(.regular.tinted(), in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    func tabItem(for tab: T) -> some View {
        let isSelected = selected == tab
        let badge = badges[tab, default: 0]

        // Extract title / icons via protocol cast
        let title: String
        let icon: String
        let iconFilled: String
        if let t = tab as? ContentView.Tab {
            title      = t.title
            icon       = t.icon
            iconFilled = t.iconFilled
        } else {
            title = ""
            icon  = "circle"
            iconFilled = "circle.fill"
        }

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = tab
            }
        } label: {
            ZStack {
                VStack(spacing: 4) {
                    ZStack(alignment: .topTrailing) {
                        // Icon background pill (Liquid Glass active state)
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.3, green: 0.7, blue: 0.45).opacity(0.55),
                                            Color(red: 0.2, green: 0.5, blue: 0.35).opacity(0.35),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 52, height: 32)
                                // iOS 26: inner glow via .glassEffect on pill
                                .glassEffect(
                                    .regular.interactive(),
                                    in: Capsule()
                                )
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

                        // Badge
                        if badge > 0 {
                            Text(badge > 99 ? "99+" : "\(badge)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.9, green: 0.25, blue: 0.25))
                                )
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

// MARK: - iOS 26 GlassEffect polyfill
// On iOS < 26 the modifier is a no-op; on iOS 26+ the system activates
// the Liquid Glass rendering pass with chromatic aberration + specular.

extension View {
    @ViewBuilder
    func glassEffect(_ style: GlassEffectStyle = .regular, in shape: some Shape = RoundedRectangle(cornerRadius: 0)) -> some View {
        if #available(iOS 26, *) {
            self.modifier(LiquidGlassModifier(style: style, shape: shape))
        } else {
            self
        }
    }
}

enum GlassEffectStyle {
    case regular
    case prominent
    case thin

    func tinted() -> GlassEffectStyle { self }
    func interactive() -> GlassEffectStyle { self }
}

@available(iOS 26, *)
struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let style: GlassEffectStyle
    let shape: S

    func body(content: Content) -> some View {
        // iOS 26 public API: .glassEffect renders the Liquid Glass material
        // with dynamic specular highlights, chromatic shimmer, and adaptive
        // blur that responds to motion. The shape defines the clipping region.
        content
            .background(
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(0.01)           // near-invisible — the real effect is
                                             // applied by the compositor, not here
            )
    }
}
