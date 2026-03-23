import SwiftUI
import AVFoundation

private let accent  = Color(red: 0.35, green: 0.80, blue: 0.52)
private let bgChat  = Color(red: 0.07, green: 0.10, blue: 0.07)
private let outBubble = Color(red: 0.20, green: 0.40, blue: 0.26)
private let inBubble  = Color(red: 0.17, green: 0.20, blue: 0.17)
private let barBg     = Color(red: 0.10, green: 0.13, blue: 0.10)

// MARK: - Chat View

struct ChatView: View {
    let peerId:   Int
    let peerName: String

    @StateObject private var vm: ChatViewModel
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var input = ""
    @State private var scrolledToBottom = true
    @Environment(\.dismiss) private var dismiss

    init(peerId: Int, peerName: String) {
        self.peerId   = peerId
        self.peerName = peerName
        _vm = StateObject(wrappedValue: ChatViewModel(peerId: peerId, peerName: peerName))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MathWallpaper().ignoresSafeArea()
            VStack(spacing: 0) {
                messageList
                if !vm.typingUserIds.isEmpty {
                    typingBar
                }
                InputBar(text: $input, isSending: vm.isSending) {
                    Task { await vm.send(text: input); input = "" }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { chatToolbar }
        .toolbarBackground(barBg.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .alert("Ошибка", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
    }

    // MARK: - Message List

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    // Load more
                    if vm.hasMore {
                        Button { Task { await vm.loadMore() } } label: {
                            if vm.isLoading {
                                ProgressView().tint(accent).padding()
                            } else {
                                Text("Загрузить ранее")
                                    .font(.system(size: 13))
                                    .foregroundColor(accent)
                                    .padding(10)
                            }
                        }
                    } else if vm.isLoading {
                        ProgressView().tint(accent).padding()
                    }

                    ForEach(Array(vm.messages.enumerated()), id: \.element.id) { index, msg in
                        // Date separator
                        if vm.shouldShowDate(at: index) {
                            dateSeparator(msg.date)
                        }

                        if msg.isService {
                            ServiceBubble(msg: msg, profiles: vm.profiles)
                        } else {
                            BubbleView(
                                msg: msg,
                                profiles: vm.profiles,
                                isRead: vm.isRead(msg),
                                showSender: vm.isGroupChat && !msg.isOutgoing,
                                audioPlayer: audioPlayer
                            )
                            .id(msg.id)
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Date Separator

    func dateSeparator(_ ts: Int) -> some View {
        Text(ts.vkDateSeparator)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color(white: 0.6))
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.35)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    // MARK: - Typing

    var typingBar: some View {
        HStack(spacing: 6) {
            TypingDots()
            let names = vm.typingUserIds.compactMap { vm.profiles[$0]?.firstName }
            let text = names.isEmpty ? "печатает..." : "\(names.joined(separator: ", ")) печатает..."
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.5))
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
        .background(barBg)
    }

    // MARK: - Toolbar

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
                Group {
                    if !vm.typingUserIds.isEmpty {
                        Text("печатает...")
                    } else if let u = vm.peerUser {
                        Text(u.isOnline ? (u.isMobile ? "в сети с телефона" : "в сети") : u.statusText)
                    } else if vm.isGroupChat {
                        Text("беседа")
                    } else {
                        Text("")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(vm.peerUser?.isOnline == true || !vm.typingUserIds.isEmpty ? accent : Color(white: 0.5))
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            VKAvatarView(url: nil, name: peerName, size: 34)
        }
    }
}

// MARK: - Service Message Bubble

struct ServiceBubble: View {
    let msg: VKAPIMessage
    let profiles: [Int: VKUser]

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(Color(white: 0.55))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.25)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    var text: String {
        guard let action = msg.action else { return "" }
        let name = profiles[msg.fromId]?.firstName ?? ""
        let memberName = profiles[action.memberId ?? 0]?.firstName ?? ""
        switch action.type {
        case "chat_create":          return "\(name) создал беседу «\(action.text ?? "")»"
        case "chat_invite_user":
            if action.memberId == msg.fromId { return "\(name) вернулся в беседу" }
            return "\(name) пригласил \(memberName)"
        case "chat_kick_user":
            if action.memberId == msg.fromId { return "\(name) покинул беседу" }
            return "\(name) исключил \(memberName)"
        case "chat_title_update":    return "\(name) изменил название на «\(action.text ?? "")»"
        case "chat_photo_update":    return "\(name) обновил фото беседы"
        case "chat_pin_message":     return "\(name) закрепил сообщение"
        case "chat_unpin_message":   return "\(name) открепил сообщение"
        default:                     return action.type
        }
    }
}

// MARK: - Bubble View

struct BubbleView: View {
    let msg: VKAPIMessage
    let profiles: [Int: VKUser]
    let isRead: Bool
    let showSender: Bool
    let audioPlayer: AudioPlayerService

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if msg.isOutgoing { Spacer(minLength: 44) }

            if !msg.isOutgoing {
                VKAvatarView(
                    url: profiles[msg.fromId]?.avatarURL,
                    name: profiles[msg.fromId]?.fullName ?? "?",
                    size: 28
                )
            }

            VStack(alignment: msg.isOutgoing ? .trailing : .leading, spacing: 2) {
                // Sender name in group chats
                if showSender {
                    Text(profiles[msg.fromId]?.firstName ?? "")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(senderColor(msg.fromId))
                        .padding(.horizontal, 12)
                }

                bubble
            }

            if !msg.isOutgoing { Spacer(minLength: 44) }
        }
        .padding(.vertical, 1)
    }

    // MARK: - Bubble content

    @ViewBuilder
    var bubble: some View {
        // Reply + content
        let hasReply = msg.replyMessage != nil
        let hasFwd   = !(msg.fwdMessages ?? []).isEmpty

        if let sticker = msg.attachments?.first(where: { $0.type == "sticker" })?.sticker {
            // Sticker — no bubble
            VStack(alignment: msg.isOutgoing ? .trailing : .leading) {
                stickerView(sticker)
                timeAndCheck.padding(.horizontal, 4)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if hasReply, let reply = msg.replyMessage {
                    replyPreview(reply)
                }

                if hasFwd {
                    fwdPreview(msg.fwdMessages!)
                }

                // Attachments
                if let atts = msg.attachments, !atts.isEmpty {
                    ForEach(Array(atts.enumerated()), id: \.offset) { _, att in
                        attachmentView(att)
                    }
                }

                // Text + time row
                if !msg.text.isEmpty || (!hasReply && (msg.attachments ?? []).isEmpty && !hasFwd) {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(msg.text.isEmpty ? " " : msg.text)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Spacer(minLength: 0)
                        metaInfo
                    }
                } else {
                    HStack { Spacer(); metaInfo }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(msg.isOutgoing ? outBubble : inBubble)
            )
        }
    }

    // MARK: - Meta (time + edited + read)

    var metaInfo: some View {
        timeAndCheck.padding(.bottom, 1)
    }

    var timeAndCheck: some View {
        HStack(spacing: 3) {
            if msg.isEdited {
                Text("ред.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.45))
            }
            Text(msg.date.vkTime)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.55))
            if msg.isOutgoing {
                Image(systemName: isRead ? "checkmark.circle" : "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isRead ? accent : Color(white: 0.55))
            }
        }
    }

    // MARK: - Reply

    func replyPreview(_ reply: VKReplyMessage) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accent)
                .frame(width: 3, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(profiles[reply.fromId]?.firstName ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
                    .lineLimit(1)
                Text(reply.text.isEmpty ? attachmentLabel(reply.attachments) : reply.text)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.6))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Forward

    func fwdPreview(_ fwds: [VKReplyMessage]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(fwds) { fwd in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.4))
                        .frame(width: 2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profiles[fwd.fromId]?.firstName ?? "Пересланное")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(white: 0.7))
                            .lineLimit(1)
                        Text(fwd.text.isEmpty ? attachmentLabel(fwd.attachments) : fwd.text)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    // MARK: - Attachments

    @ViewBuilder
    func attachmentView(_ att: VKAttachment) -> some View {
        switch att.type {
        case "photo":         photoView(att.photo)
        case "video":         videoView(att.video)
        case "audio_message": voiceView(att.audioMessage)
        case "video_message": videoMessageView(att.videoMessage)
        case "doc":           docView(att.doc)
        case "audio":         audioView(att.audio)
        case "link":          linkView(att.link)
        case "wall":          wallView(att.wall)
        case "graffiti":      graffitiView(att.graffiti)
        case "gift":          giftView(att.gift)
        case "poll":          pollView(att.poll)
        default:
            HStack(spacing: 6) {
                Image(systemName: "paperclip").foregroundColor(accent)
                Text(att.type).foregroundColor(Color(white: 0.6))
            }
        }
    }

    // Photo
    @ViewBuilder
    func photoView(_ photo: VKPhoto?) -> some View {
        if let url = photo?.bestURL {
            let ratio = photo?.aspectRatio ?? 1.0
            let w: CGFloat = min(260, max(120, 260))
            let h: CGFloat = min(300, max(80, w / ratio))
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(maxWidth: w, maxHeight: h).clipped()
                default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.15))
                        .frame(width: w, height: h)
                        .overlay(ProgressView().tint(accent))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // Video
    @ViewBuilder
    func videoView(_ video: VKVideo?) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let url = video?.thumbURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(width: 240, height: 160).clipped()
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.15))
                            .frame(width: 240, height: 160)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.15))
                    .frame(width: 240, height: 160)
            }
            // Play button
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "play.fill").foregroundColor(.white).font(.system(size: 18)))
                .position(x: 120, y: 80)
            // Duration
            if let d = video?.durationFormatted, !d.isEmpty {
                Text(d)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(8)
            }
        }
        if let title = video?.title, !title.isEmpty {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(accent)
                .lineLimit(2)
        }
    }

    // Voice message with waveform
    func voiceView(_ audio: VKAudioMessage?) -> some View {
        HStack(spacing: 8) {
            let url = audio?.linkMp3 ?? audio?.linkOgg ?? ""
            let playing = audioPlayer.currentURL == url && audioPlayer.isPlaying

            Button { audioPlayer.toggle(url: url) } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundColor(accent)
                    .frame(width: 32, height: 32)
            }

            // Waveform
            WaveformView(
                waveform: audio?.waveform ?? [],
                progress: audioPlayer.currentURL == url ? audioPlayer.progress : 0
            )
            .frame(height: 24)
            .frame(maxWidth: 140)

            Text(formatDuration(audio?.duration ?? 0))
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.6))
                .monospacedDigit()
        }
    }

    // Video message (кружок)
    @ViewBuilder
    func videoMessageView(_ vm: VKVideoMessage?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let url = vm?.previewURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                    default:
                        Circle()
                            .fill(Color(white: 0.15))
                            .frame(width: 200, height: 200)
                            .overlay(ProgressView().tint(accent))
                    }
                }
            } else {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "video.circle")
                            .font(.system(size: 40))
                            .foregroundColor(Color(white: 0.4))
                    )
            }
            // Play overlay
            Circle()
                .fill(Color.black.opacity(0.3))
                .frame(width: 200, height: 200)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.8))
                )
                .opacity(0.5)
            // Duration badge
            HStack(spacing: 3) {
                if let d = vm?.duration { Text(formatDuration(d)).font(.system(size: 11)).foregroundColor(.white) }
                timeAndCheck
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.5)))
            .padding(8)
        }
    }

    // Document
    func docView(_ doc: VKDoc?) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: docIcon(doc?.ext))
                    .font(.system(size: 20))
                    .foregroundColor(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(doc?.title ?? "Документ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(doc?.ext?.uppercased() ?? "") · \(doc?.sizeFormatted ?? "")")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.5))
            }
        }
    }

    // Audio
    func audioView(_ audio: VKAudio?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(accent.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(audio?.title ?? "Аудио")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(audio?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.5))
                    .lineLimit(1)
            }
            Spacer()
            Text(audio?.durationFormatted ?? "")
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.5))
                .monospacedDigit()
        }
    }

    // Link
    func linkView(_ link: VKLink?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let photo = link?.photo, let url = photo.thumbURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                            .frame(height: 120).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            if let title = link?.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(accent)
                    .lineLimit(2)
            }
            if let caption = link?.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.5))
                    .lineLimit(1)
            }
        }
    }

    // Wall post
    func wallView(_ wall: VKWall?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "doc.richtext")
                    .foregroundColor(accent)
                Text("Запись на стене")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(accent)
            }
            if let text = wall?.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .lineLimit(4)
            }
        }
    }

    // Graffiti
    @ViewBuilder
    func graffitiView(_ graffiti: VKGraffiti?) -> some View {
        if let url = graffiti?.imageURL {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                }
            }
        }
    }

    // Gift
    @ViewBuilder
    func giftView(_ gift: VKGift?) -> some View {
        if let url = gift?.thumbURL {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFit()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        } else {
            HStack {
                Image(systemName: "gift.fill").foregroundColor(accent)
                Text("Подарок").foregroundColor(.white)
            }
        }
    }

    // Poll
    func pollView(_ poll: VKPoll?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar").foregroundColor(accent)
                Text(poll?.question ?? "Опрос")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            ForEach(poll?.answers ?? []) { answer in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(answer.text)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(answer.votes ?? 0)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.5))
                    }
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent.opacity(0.3))
                            .frame(width: g.size.width * (answer.rate ?? 0) / 100)
                    }
                    .frame(height: 3)
                }
            }
            Text("\(poll?.votes ?? 0) голосов")
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.5))
        }
    }

    // Sticker
    @ViewBuilder
    func stickerView(_ sticker: VKSticker) -> some View {
        if let url = sticker.bestURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit().frame(width: 150, height: 150)
                default: Color.clear.frame(width: 150, height: 150)
                }
            }
        } else {
            Text("🎭").font(.system(size: 80))
        }
    }

    // MARK: - Helpers

    func attachmentLabel(_ atts: [VKAttachment]?) -> String {
        guard let att = atts?.first else { return "Вложение" }
        switch att.type {
        case "photo":         return "📷 Фото"
        case "video":         return "🎬 Видео"
        case "audio_message": return "🎤 Голосовое"
        case "video_message": return "📹 Кружок"
        case "sticker":       return "🎭 Стикер"
        case "doc":           return "📎 Документ"
        case "audio":         return "🎵 Аудио"
        case "link":          return "🔗 Ссылка"
        case "wall":          return "📝 Стена"
        case "gift":          return "🎁 Подарок"
        case "poll":          return "📊 Опрос"
        default:              return att.type
        }
    }

    func senderColor(_ fromId: Int) -> Color {
        let hue = Double(abs(fromId) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.85)
    }

    func docIcon(_ ext: String?) -> String {
        switch ext?.lowercased() {
        case "pdf":                         return "doc.fill"
        case "doc", "docx":                 return "doc.text.fill"
        case "xls", "xlsx":                 return "tablecells.fill"
        case "ppt", "pptx":                 return "rectangle.fill.on.rectangle.fill"
        case "zip", "rar", "7z", "tar":     return "archivebox.fill"
        case "mp3", "ogg", "wav", "flac":   return "music.note"
        case "mp4", "avi", "mkv", "mov":    return "film.fill"
        case "jpg", "jpeg", "png", "gif":   return "photo.fill"
        default:                            return "doc.fill"
        }
    }

    func formatDuration(_ d: Int) -> String {
        String(format: "%d:%02d", d / 60, d % 60)
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let waveform: [Int]
    let progress: Double

    var body: some View {
        GeometryReader { g in
            let bars = normalizedBars(width: g.size.width)
            HStack(spacing: 1.5) {
                ForEach(Array(bars.enumerated()), id: \.offset) { i, h in
                    let filled = Double(i) / Double(max(bars.count - 1, 1)) <= progress
                    RoundedRectangle(cornerRadius: 1)
                        .fill(filled ? accent : accent.opacity(0.35))
                        .frame(width: 2.5, height: max(2, h * g.size.height))
                }
            }
            .frame(height: g.size.height, alignment: .center)
        }
    }

    func normalizedBars(width: CGFloat) -> [CGFloat] {
        let count = max(1, Int(width / 4))
        guard !waveform.isEmpty else { return Array(repeating: 0.1, count: count) }
        let maxVal = CGFloat(waveform.max() ?? 1)
        // Resample
        var result: [CGFloat] = []
        for i in 0..<count {
            let idx = Int(Double(i) / Double(count) * Double(waveform.count))
            let val = idx < waveform.count ? CGFloat(waveform[idx]) / maxVal : 0.1
            result.append(max(0.08, val))
        }
        return result
    }
}

// MARK: - Typing Dots Animation

struct TypingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(white: 0.5))
                    .frame(width: 5, height: 5)
                    .offset(y: phase == i ? -3 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) { phase = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) { phase = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) { phase = 2 }
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
            .disabled(isSending || text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(barBg.opacity(0.97))
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
                Color(red: 0.07, green: 0.09, blue: 0.07)
                Canvas { ctx, size in
                    let cols = 4; let cw = size.width / CGFloat(cols)
                    let rh = size.height / CGFloat(formulas.count)
                    for (r, f) in formulas.enumerated() {
                        for c in 0..<cols {
                            let x = CGFloat(c) * cw + 8
                            let y = CGFloat(r) * rh + rh * 0.5
                            ctx.draw(
                                Text(f)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundColor(Color(red: 0.80, green: 0.75, blue: 0.18).opacity(0.14)),
                                at: CGPoint(x: x, y: y), anchor: .leading
                            )
                        }
                    }
                }
            }
        }
    }
}
