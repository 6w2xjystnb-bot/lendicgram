import SwiftUI

private let accent  = Color(red: 0.35, green: 0.80, blue: 0.52)
private let bgChat  = Color(red: 0.07, green: 0.10, blue: 0.07)

// MARK: - Chat View

struct ChatView: View {
    let peerId:   Int
    let peerName: String

    @StateObject private var vm: ChatViewModel
    @State private var input = ""
    @Environment(\.dismiss) private var dismiss

    init(peerId: Int, peerName: String) {
        self.peerId   = peerId
        self.peerName = peerName
        _vm = StateObject(wrappedValue: ChatViewModel(peerId: peerId, peerName: peerName))
    }

    var body: some View {
        ZStack {
            MathWallpaper().ignoresSafeArea()
            VStack(spacing: 0) {
                messageList
                InputBar(text: $input, isSending: vm.isSending) {
                    Task { await vm.send(text: input); input = "" }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { chatToolbar }
        .toolbarBackground(Color(red:0.10,green:0.13,blue:0.10).opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Ошибка", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
    }

    // MARK: Message List

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    if vm.isLoading {
                        ProgressView().tint(accent).padding()
                    }
                    ForEach(vm.messages) { msg in
                        BubbleView(msg: msg, profiles: vm.profiles)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    var chatToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    Text("Чаты").font(.system(size: 17))
                }
                .foregroundColor(accent)
            }
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(peerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("в сети")
                    .font(.system(size: 12))
                    .foregroundColor(accent)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            VKAvatarView(url: nil, name: peerName, size: 34)
        }
    }
}

// MARK: - Bubble

struct BubbleView: View {
    let msg:      VKAPIMessage
    let profiles: [Int: VKUser]

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if msg.isOutgoing { Spacer(minLength: 52) }

            // Incoming avatar
            if !msg.isOutgoing {
                VKAvatarView(url: profiles[msg.fromId]?.avatarURL, name: profiles[msg.fromId]?.fullName ?? "?", size: 28)
            }

            bubble

            if !msg.isOutgoing { Spacer(minLength: 52) }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    var bubble: some View {
        if let att = msg.attachments?.first {
            attachmentBubble(att)
        } else if !msg.text.isEmpty {
            textBubble(msg.text)
        } else {
            textBubble("(пустое сообщение)")
        }
    }

    func textBubble(_ text: String) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)
            timeAndCheck
                .padding(.bottom, 1)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(msg.isOutgoing
                      ? Color(red:0.20,green:0.40,blue:0.26)
                      : Color(red:0.17,green:0.20,blue:0.17))
        )
    }

    @ViewBuilder
    func attachmentBubble(_ att: VKAttachment) -> some View {
        switch att.type {
        case "photo":
            photoView(att.photo)
        case "sticker":
            stickerView(att.sticker)
        case "audio_message":
            voiceView(att.audioMessage)
        default:
            textBubble("📎 \(att.type)")
        }
    }

    @ViewBuilder
    func photoView(_ photo: VKPhoto?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let url = photo?.bestURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(width: 220, height: 220).clipped()
                    default:
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.18))
                            .frame(width: 220, height: 220)
                            .overlay(ProgressView().tint(accent))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.18))
                    .frame(width: 220, height: 220)
                    .overlay(Image(systemName: "photo").font(.system(size: 40)).foregroundColor(Color(white: 0.4)))
            }
            timeAndCheck
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.45)))
                .padding(6)
        }
    }

    @ViewBuilder
    func stickerView(_ sticker: VKSticker?) -> some View {
        if let url = sticker?.bestURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit().frame(width: 140, height: 140)
                default: Color.clear.frame(width: 140, height: 140)
                }
            }
        } else {
            Text("🎭").font(.system(size: 80))
        }
    }

    func voiceView(_ audio: VKAudioMessage?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 20))
                .foregroundColor(accent)
            RoundedRectangle(cornerRadius: 2)
                .fill(accent.opacity(0.5))
                .frame(width: 120, height: 3)
            Text("\(audio?.duration ?? 0)с")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.7))
            timeAndCheck
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(msg.isOutgoing
                  ? Color(red:0.20,green:0.40,blue:0.26)
                  : Color(red:0.17,green:0.20,blue:0.17)))
    }

    var timeAndCheck: some View {
        HStack(spacing: 3) {
            Text(msg.date.vkTime)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.55))
            if msg.isOutgoing {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.55))
            }
        }
    }
}

// MARK: - Input Bar

struct InputBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button { } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 22))
                    .foregroundColor(Color(white: 0.5))
            }
            HStack {
                TextField("", text: $text,
                          prompt: Text("Сообщение").foregroundColor(Color(white: 0.30)))
                    .foregroundColor(.white)
                Button { } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundColor(Color(white: 0.5))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.14)))

            Button(action: onSend) {
                Group {
                    if isSending {
                        ProgressView().tint(accent).frame(width: 26, height: 26)
                    } else {
                        Image(systemName: text.isEmpty ? "mic" : "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(text.isEmpty ? Color(white: 0.5) : accent)
                    }
                }
            }
            .disabled(isSending)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(red:0.10,green:0.13,blue:0.10).opacity(0.97))
    }
}

// MARK: - Math Wallpaper

struct MathWallpaper: View {
    private let formulas = [
        "a_n=a₁+d(n-1)", "sin²x+cos²x=1", "∫eˣdx=eˣ+C",
        "∑(n→∞)", "π≈3.14159", "√(a²+b²)=c", "y=ctg(x)",
        "tg(−x)=−tg(x)", "log_a(b·c)", "x₁+x₂=−b/a",
        "e≈2.71828", "4x+(a+b)²", "limₓ→₀ sinx/x=1",
        "d/dx(eˣ)=eˣ", "∫₀^π sinx dx=2",
    ]
    var body: some View {
        GeometryReader { g in
            ZStack {
                Color(red:0.07,green:0.09,blue:0.07)
                Canvas { ctx, size in
                    let cols = 4; let cw = size.width / CGFloat(cols)
                    let rh   = size.height / CGFloat(formulas.count)
                    for (r, f) in formulas.enumerated() {
                        for c in 0..<cols {
                            let x = CGFloat(c) * cw + 8
                            let y = CGFloat(r) * rh + rh * 0.5
                            ctx.draw(
                                Text(f)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundColor(Color(red:0.80,green:0.75,blue:0.18).opacity(0.14)),
                                at: CGPoint(x: x, y: y), anchor: .leading
                            )
                        }
                    }
                }
            }
        }
    }
}
