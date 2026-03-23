import SwiftUI

struct ChatDetailView: View {
    let chat: VKChat
    @State private var messageText = ""
    @Environment(\.dismiss) private var dismiss

    var messages: [VKMessage] {
        VKMessage.mockVankinsMessages
    }

    var body: some View {
        ZStack {
            // Math wallpaper background
            MathWallpaperView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Pinned message banner
                PinnedMessageBannerView()

                // Messages scroll
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(messages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                // Input bar
                MessageInputBarView(text: $messageText)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 6) {
                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("17")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.5))
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(chat.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text("был(а) только что")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.55))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                AvatarView(name: chat.name, color: chat.avatarColor, size: 34)
            }
        }
        .toolbarBackground(Color(red: 0.1, green: 0.13, blue: 0.1).opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Pinned Message

struct PinnedMessageBannerView: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color(red: 0.35, green: 0.75, blue: 0.5))
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 1) {
                Text("Закреплённое сообщение")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.5))
                Text("1150₽")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.8))
            }

            Spacer()

            Button { } label: {
                Image(systemName: "pin.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.5))
                    .rotationEffect(.degrees(45))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.1, green: 0.13, blue: 0.1).opacity(0.92))
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: VKMessage

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 60) }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 0) {
                switch message.contentType {
                case .text:
                    textBubble
                case .videoMessage:
                    videoMessageBubble
                case .image:
                    imageBubble
                case .sticker:
                    stickerBubble
                }
            }

            if !message.isOutgoing { Spacer(minLength: 60) }
        }
    }

    // MARK: Text bubble
    var textBubble: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if let text = message.text {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(message.isOutgoing
                      ? Color(red: 0.2, green: 0.38, blue: 0.26)
                      : Color(red: 0.18, green: 0.21, blue: 0.18))
        )
        .overlay(alignment: message.isOutgoing ? .bottomTrailing : .bottomLeading) {
            timeLabel
                .padding(message.isOutgoing ? .trailing : .leading, 8)
                .padding(.bottom, 5)
        }
        .padding(.bottom, 2)
    }

    // MARK: Video message (круглое)
    var videoMessageBubble: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(white: 0.22))
                .frame(width: 220, height: 220)
                .overlay(
                    ZStack {
                        // Simulated video content
                        LinearGradient(
                            colors: [Color(white: 0.35), Color(white: 0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(Circle())

                        Circle()
                            .stroke(Color(white: 0.3), lineWidth: 2)
                    }
                )

            HStack(spacing: 6) {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .padding(10)
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                Text("0:03")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.7))
                Spacer()
                timeLabel
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    // MARK: Image bubble
    var imageBubble: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.2, blue: 0.35),
                            Color(red: 0.15, green: 0.1, blue: 0.2),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    // Disco ball placeholder
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white, Color(white: 0.7), Color(white: 0.4)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                            .overlay(
                                Text("🪩")
                                    .font(.system(size: 55))
                            )
                        VStack {
                            Spacer()
                            Image(systemName: "heart.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
                                .offset(x: -30, y: -10)
                        }
                    }
                )

            timeLabel
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4)))
                .padding(6)
        }
    }

    // MARK: Sticker
    var stickerBubble: some View {
        Text(message.stickerEmoji ?? "🤬")
            .font(.system(size: 60))
    }

    // MARK: Time + checkmark
    var timeLabel: some View {
        HStack(spacing: 3) {
            Text(message.time)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.55))
            if message.isOutgoing {
                Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.55))
            }
        }
    }
}

// MARK: - Input Bar

struct MessageInputBarView: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Button { } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 22))
                    .foregroundColor(Color(white: 0.55))
            }

            HStack {
                TextField("", text: $text,
                          prompt: Text("Сообщение")
                            .foregroundColor(Color(white: 0.35)))
                    .foregroundColor(.white)
                    .font(.system(size: 16))

                Button { } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundColor(Color(white: 0.55))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(white: 0.14))
            )

            Button { } label: {
                Image(systemName: text.isEmpty ? "mic" : "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(
                        text.isEmpty
                        ? Color(white: 0.55)
                        : Color(red: 0.35, green: 0.75, blue: 0.5)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.1, green: 0.13, blue: 0.1).opacity(0.95))
    }
}

// MARK: - Math Wallpaper

struct MathWallpaperView: View {
    let formulas = [
        "a_n = a₁ + d(n-1)", "sin²x + cos²x = 1",
        "∫eˣdx = eˣ + C", "∑(n=1)→∞", "π = 3.14",
        "√(a²+b²)", "y = ctgx", "tg(−x) = −tgx",
        "log_a(b)", "x₁+x₂ = −b/a", "cos²x − sin²x",
        "2x² = 5", "e ≈ 2.718", "4x + (a+b)²",
        "80:D=A0:C", "13x² − b(p−c)",
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.08, green: 0.11, blue: 0.08)

                // Grid of formulas as texture
                Canvas { ctx, size in
                    let rows = 12
                    let cols = 5
                    let cw = size.width / CGFloat(cols)
                    let ch = size.height / CGFloat(rows)

                    for r in 0..<rows {
                        for c in 0..<cols {
                            let formula = formulas[(r * cols + c) % formulas.count]
                            let x = CGFloat(c) * cw + cw * 0.1
                            let y = CGFloat(r) * ch + ch * 0.5
                            let text = Text(formula)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(red: 0.8, green: 0.75, blue: 0.2).opacity(0.18))
                            ctx.draw(text, at: CGPoint(x: x, y: y), anchor: .leading)
                        }
                    }
                }
            }
        }
    }
}
