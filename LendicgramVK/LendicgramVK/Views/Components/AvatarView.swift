import SwiftUI

struct AvatarView: View {
    let name: String
    let color: Color
    let size: CGFloat

    var initials: String {
        let parts = name.components(separatedBy: .whitespaces)
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

struct PinnedIndicator: View {
    var body: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 11))
            .foregroundColor(Color(white: 0.45))
            .rotationEffect(.degrees(45))
    }
}

struct CheckmarkView: View {
    let isDouble: Bool
    var body: some View {
        Image(systemName: isDouble ? "checkmark.message.fill" : "checkmark")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(white: 0.5))
    }
}
