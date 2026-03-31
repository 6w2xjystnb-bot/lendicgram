import SwiftUI

// MARK: - Cached Async Image

/// Drop-in replacement for AsyncImage that caches results to memory + disk.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url?.absoluteString ?? "") {
            guard let url else { uiImage = nil; return }
            uiImage = await ImageCache.shared.load(url: url)
        }
    }
}

// MARK: - VKAvatarView (cached)

struct VKAvatarView: View {
    let url:  URL?
    let name: String
    let size: CGFloat

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    avatarPlaceholder
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color(hue: nameHue, saturation: 0.55, brightness: 0.72),
                         Color(hue: nameHue, saturation: 0.70, brightness: 0.50)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private var initials: String {
        let parts = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if parts.count >= 2 { return String(parts[0].prefix(1)) + String(parts[1].prefix(1)) }
        return String(name.prefix(2)).uppercased()
    }

    private var nameHue: Double {
        let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Double(abs(hash) % 360) / 360.0
    }
}
