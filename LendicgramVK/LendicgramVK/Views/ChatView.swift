import SwiftUI

private let accent = Color(red: 0.35, green: 0.80, blue: 0.52)

// MARK: - Chat View

struct ChatView: View {
    let chat: VKChat
    @State private var input = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            MathWallpaper().ignoresSafeArea()

            VStack(spacing: 0) {
                PinnedBanner()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(VKMessage.vankinsChat) { msg in
                                BubbleView(msg: msg).id(msg.id)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                    .onAppear {
                        if let last = VKMessage.vankinsChat.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                InputBar(text: $input)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                        Text("17").font(.system(size: 17))
                    }
                    .foregroundColor(accent)
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(chat.name).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Text("был(а) только что").font(.system(size: 12)).foregroundColor(Color(white: 0.55))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Circle()
                    .fill(chat.avatarColor)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(chat.name.prefix(2).uppercased())
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
        }
        .toolbarBackground(Color(red:0.10,green:0.13,blue:0.10).opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Pinned Banner

struct PinnedBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color(red:0.35,green:0.80,blue:0.52))
                .frame(width: 3).cornerRadius(2)
            VStack(alignment: .leading, spacing: 1) {
                Text("Закреплённое сообщение")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red:0.35,green:0.80,blue:0.52))
                Text("1150₽")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.8))
            }
            Spacer()
            Image(systemName: "pin.fill")
                .foregroundColor(Color(white: 0.45))
                .rotationEffect(.degrees(45))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(red:0.10,green:0.13,blue:0.10).opacity(0.92))
    }
}

// MARK: - Message Bubble

struct BubbleView: View {
    let msg: VKMessage

    var body: some View {
        HStack {
            if msg.isOutgoing { Spacer(minLength: 64) }
            content
            if !msg.isOutgoing { Spacer(minLength: 64) }
        }
    }

    @ViewBuilder var content: some View {
        switch msg.type {
        case .text:     textBubble
        case .videoNote: videoNote
        case .photo:    photoBubble
        case .sticker:  Text("🤬").font(.system(size: 60))
        }
    }

    var textBubble: some View {
        VStack(alignment: msg.isOutgoing ? .trailing : .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                if let t = msg.text {
                    Text(t)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 22)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(msg.isOutgoing
                          ? Color(red:0.20,green:0.38,blue:0.26)
                          : Color(red:0.18,green:0.21,blue:0.18))
            )
            .overlay(alignment: msg.isOutgoing ? .bottomTrailing : .bottomLeading) {
                timeLabel.padding(msg.isOutgoing ? .trailing : .leading, 10).padding(.bottom, 6)
            }
        }
    }

    var videoNote: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(LinearGradient(colors:[Color(white:0.30),Color(white:0.18)],
                                     startPoint:.topLeading, endPoint:.bottomTrailing))
                .frame(width: 210, height: 210)

            HStack(spacing: 5) {
                Image(systemName: "speaker.slash.fill").font(.system(size: 13))
                Text("0:03").font(.system(size: 12))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .padding(10)
        }
        .overlay(alignment: .bottomTrailing) {
            timeLabel.padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4)))
                .padding(6)
        }
    }

    var photoBubble: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors:[Color(red:0.28,green:0.18,blue:0.35),Color(red:0.14,green:0.10,blue:0.20)],
                    startPoint:.topLeading, endPoint:.bottomTrailing))
                .frame(width: 200, height: 200)
                .overlay(Text("🪩").font(.system(size: 55)))
            timeLabel.padding(6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.45)))
                .padding(6)
        }
    }

    var timeLabel: some View {
        HStack(spacing: 3) {
            Text(msg.time).font(.system(size: 11)).foregroundColor(Color(white: 0.55))
            if msg.isOutgoing {
                Image(systemName: msg.isRead ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.55))
            }
        }
    }
}

// MARK: - Input Bar

struct InputBar: View {
    @Binding var text: String
    private let accent = Color(red:0.35,green:0.80,blue:0.52)

    var body: some View {
        HStack(spacing: 10) {
            Button { } label: {
                Image(systemName: "paperclip").font(.system(size: 22)).foregroundColor(Color(white:0.5))
            }
            HStack {
                TextField("", text: $text,
                          prompt: Text("Сообщение").foregroundColor(Color(white:0.30)))
                    .foregroundColor(.white)
                Button { } label: {
                    Image(systemName: "face.smiling").font(.system(size: 22)).foregroundColor(Color(white:0.5))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color(white:0.14)))

            Button { } label: {
                Image(systemName: text.isEmpty ? "mic" : "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(text.isEmpty ? Color(white:0.5) : accent)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(red:0.10,green:0.13,blue:0.10).opacity(0.96))
    }
}

// MARK: - Math Wallpaper

struct MathWallpaper: View {
    private let rows = ["a_n=a₁+d(n-1)", "sin²x+cos²x=1", "∫eˣdx=eˣ+C", "∑(n→∞)", "π≈3.14",
                        "√(a²+b²)", "y=ctgx", "tg(−x)=−tgx", "log_a(b)", "x₁+x₂=−b/a",
                        "cos²x−sin²x", "2x²=5", "e≈2.718", "4x+(a+b)²", "80:D=A0:C"]
    var body: some View {
        GeometryReader { g in
            ZStack {
                Color(red:0.07,green:0.10,blue:0.07)
                Canvas { ctx, size in
                    let cols = 5; let cw = size.width/CGFloat(cols)
                    let rowH = size.height/CGFloat(rows.count)
                    for (r, formula) in rows.enumerated() {
                        for c in 0..<cols {
                            let x = CGFloat(c)*cw + cw*0.1
                            let y = CGFloat(r)*rowH + rowH*0.5
                            ctx.draw(
                                Text(formula)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color(red:0.80,green:0.75,blue:0.20).opacity(0.17)),
                                at: CGPoint(x: x, y: y), anchor: .leading
                            )
                        }
                    }
                }
            }
        }
    }
}
