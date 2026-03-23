import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Custom Views

struct LiquidGlass: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Colors (shared)

private let outBubble = Color(red: 0.24, green: 0.52, blue: 0.88)
private let inBubble  = Color(.secondarySystemBackground)

// MARK: - Chat View

struct ChatView: View {
    let peerId:   Int
    let peerName: String

    @StateObject private var vm: ChatViewModel
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var input         = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss

    init(peerId: Int, peerName: String) {
        self.peerId   = peerId
        self.peerName = peerName
        _vm = StateObject(wrappedValue: ChatViewModel(peerId: peerId, peerName: peerName))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Subtle wallpaper
            TGWallpaper().ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                if !vm.typingUserIds.isEmpty { typingBar }
                inputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { chatToolbar }
        .toolbar(.hidden, for: .tabBar)
        .tint(tgAccent)
        .alert("Ошибка", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
        .onChange(of: pickerItems) { _, items in
            Task { await handlePickedItems(items) }
        }
    }

    // MARK: - Message List

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    if vm.hasMore {
                        Button { Task { await vm.loadMore() } } label: {
                            if vm.isLoading {
                                ProgressView().tint(tgAccent).padding()
                            } else {
                                Text("Загрузить ранее")
                                    .font(.system(size: 13))
                                    .foregroundStyle(tgAccent)
                                    .padding(10)
                            }
                        }
                    } else if vm.isLoading {
                        ProgressView().tint(tgAccent).padding()
                    }

                    ForEach(Array(vm.messages.enumerated()), id: \.element.id) { index, msg in
                        if vm.shouldShowDate(at: index) {
                            dateSeparator(msg.date)
                        }
                        if msg.isService {
                            ServiceBubble(msg: msg, profiles: vm.profiles)
                        } else {
                            BubbleView(
                                msg:         msg,
                                profiles:    vm.profiles,
                                isRead:      vm.isRead(msg),
                                showSender:  vm.isGroupChat && !msg.isOutgoing,
                                audioPlayer: audioPlayer
                            )
                            .id(msg.id)
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
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
            .foregroundStyle(Color(.secondaryLabel))
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    // MARK: - Typing

    var typingBar: some View {
        HStack(spacing: 6) {
            TypingDots()
            let names = vm.typingUserIds.compactMap { vm.profiles[$0]?.firstName }
            let text  = names.isEmpty ? "печатает..." : "\(names.joined(separator: ", ")) печатает..."
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 4)
    }

    // MARK: - Input Bar

    var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Attachment / photo picker
            PhotosPicker(selection: $pickerItems,
                         maxSelectionCount: 10,
                         matching: .any(of: [.images, .videos])) {
                Image(systemName: "paperclip")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: 36, height: 36)
            }

            // Text field with emoji
            HStack(alignment: .bottom) {
                TextField("Сообщение", text: $input, axis: .vertical)
                    .lineLimit(1...6)
                    .font(.system(size: 17))
                    .foregroundStyle(Color(.label))
                    .submitLabel(.return)

                Button {
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .padding(.horizontal, 4).padding(.vertical, 8)

            // Send / mic
            Button(action: {
                Task { await vm.send(text: input); input = "" }
            }) {
                Group {
                    if vm.isSending {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? "mic" : "arrow.up")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.secondaryLabel) : .white)
                            .frame(width: 36, height: 36)
                    }
                }
                .background(
                    Circle().fill(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.clear : tgAccent)
                )
            }
            .disabled(vm.isSending || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            ZStack {
                LiquidGlass(style: .systemUltraThinMaterial)
                Color(.secondarySystemBackground).opacity(0.3)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var chatToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { dismiss() } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Назад").font(.system(size: 17))
                }
                .foregroundStyle(tgAccent)
            }
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(peerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                Group {
                    if !vm.typingUserIds.isEmpty {
                        Text("печатает...")
                            .foregroundStyle(tgAccent)
                    } else if let u = vm.peerUser {
                        Text(u.isOnline ? (u.isMobile ? "в сети с телефона" : "в сети") : u.statusText)
                            .foregroundStyle(u.isOnline ? tgAccent : Color(.secondaryLabel))
                    } else if vm.isGroupChat {
                        Text("беседа")
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .font(.system(size: 12))
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            VKAvatarView(url: vm.peerUser?.avatarURL, name: peerName, size: 34)
        }
    }

    // MARK: - Photo Handling

    private func handlePickedItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await vm.sendPhoto(imageData: data)
            }
        }
        pickerItems = []
    }
}

// MARK: - Service Bubble

struct ServiceBubble: View {
    let msg: VKAPIMessage
    let profiles: [Int: VKUser]

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color(.secondaryLabel))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    var text: String {
        guard let action = msg.action else { return "" }
        let name       = profiles[msg.fromId]?.firstName ?? ""
        let memberName = profiles[action.memberId ?? 0]?.firstName ?? ""
        switch action.type {
        case "chat_create":         return "\(name) создал беседу «\(action.text ?? "")»"
        case "chat_invite_user":
            if action.memberId == msg.fromId { return "\(name) вернулся в беседу" }
            return "\(name) пригласил \(memberName)"
        case "chat_kick_user":
            if action.memberId == msg.fromId { return "\(name) покинул беседу" }
            return "\(name) исключил \(memberName)"
        case "chat_title_update":   return "\(name) изменил название на «\(action.text ?? "")»"
        case "chat_photo_update":   return "\(name) обновил фото беседы"
        case "chat_pin_message":    return "\(name) закрепил сообщение"
        case "chat_unpin_message":  return "\(name) открепил сообщение"
        default:                    return action.type
        }
    }
}

// MARK: - Bubble View

struct BubbleView: View {
    let msg:         VKAPIMessage
    let profiles:    [Int: VKUser]
    let isRead:      Bool
    let showSender:  Bool
    let audioPlayer: AudioPlayerService

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if msg.isOutgoing { Spacer(minLength: 52) }
            if !msg.isOutgoing {
                VKAvatarView(
                    url:  profiles[msg.fromId]?.avatarURL,
                    name: profiles[msg.fromId]?.fullName ?? "?",
                    size: 30
                )
            }

            VStack(alignment: msg.isOutgoing ? .trailing : .leading, spacing: 2) {
                if showSender {
                    Text(profiles[msg.fromId]?.firstName ?? "")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(senderColor(msg.fromId))
                        .padding(.horizontal, 12)
                }
                bubble
            }

            if !msg.isOutgoing { Spacer(minLength: 52) }
        }
        .padding(.vertical, 1)
    }

    // MARK: - Bubble content

    var isPureMedia: Bool {
        guard msg.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              msg.replyMessage == nil,
              (msg.fwdMessages ?? []).isEmpty,
              let atts = msg.attachments, atts.count == 1
        else { return false }
        
        let type = atts[0].type
        return type == "photo" || type == "video" || type == "sticker" || type == "video_message"
    }

    @ViewBuilder
    var bubble: some View {
        if isPureMedia, let att = msg.attachments?.first {
            if att.type == "sticker" {
                VStack(alignment: msg.isOutgoing ? .trailing : .leading, spacing: 2) {
                    stickerView(att.sticker!)
                    timeAndCheck.padding(.horizontal, 4)
                }
            } else if att.type == "video_message" {
                videoMessageView(att.videoMessage)
            } else if att.type == "photo" {
                ZStack(alignment: .bottomTrailing) {
                    photoView(att.photo)
                    timeAndCheck
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                        .padding(6)
                }
            } else if att.type == "video" {
                ZStack(alignment: .bottomTrailing) {
                    videoView(att.video)
                    timeAndCheck
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                        .padding(6)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if let reply = msg.replyMessage {
                    replyPreview(reply)
                }
                if let fwds = msg.fwdMessages, !fwds.isEmpty {
                    fwdPreview(fwds)
                }
                if let atts = msg.attachments, !atts.isEmpty {
                    ForEach(Array(atts.enumerated()), id: \.offset) { _, att in
                        attachmentView(att)
                    }
                }
                if !msg.text.isEmpty || (msg.attachments == nil && msg.replyMessage == nil && (msg.fwdMessages ?? []).isEmpty) {
                    HStack(alignment: .bottom, spacing: 6) {
                        Text(msg.text.isEmpty ? " " : msg.text)
                            .font(.system(size: 16))
                            .foregroundStyle(msg.isOutgoing ? Color.white : Color(.label))
                        metaInfo
                    }
                } else {
                    HStack(spacing: 0) { Spacer(minLength: 0); metaInfo }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(bubbleBg.clipShape(bubbleShape))
        }
    }

    @ViewBuilder
    private var bubbleBg: some View {
        if msg.isOutgoing {
            ZStack {
                LiquidGlass(style: .systemUltraThinMaterial)
                outBubble.opacity(0.3)
            }
        } else {
            ZStack {
                LiquidGlass(style: .systemUltraThinMaterial)
                inBubble.opacity(0.5)
            }
        }
    }

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18)
    }

    // MARK: - Meta

    var metaInfo: some View { timeAndCheck.padding(.bottom, 1) }

    var timeAndCheck: some View {
        HStack(spacing: 3) {
            if msg.isEdited {
                Text("ред.")
                    .font(.system(size: 10))
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.75) : Color(.tertiaryLabel))
            }
            Text(msg.date.vkTime)
                .font(.system(size: 11))
                .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.75) : Color(.secondaryLabel))
            if msg.isOutgoing {
                Image(systemName: isRead ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isRead ? Color.white : Color.white.opacity(0.65))
            }
        }
    }

    // MARK: - Reply

    func replyPreview(_ reply: VKReplyMessage) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(msg.isOutgoing ? Color.white.opacity(0.8) : tgAccent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(profiles[reply.fromId]?.firstName ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(msg.isOutgoing ? Color.white : tgAccent)
                    .lineLimit(1)
                Text(reply.text.isEmpty ? attachmentLabel(reply.attachments) : reply.text)
                    .font(.system(size: 13))
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.8) : Color(.secondaryLabel))
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 32)
    }

    // MARK: - Forward

    func fwdPreview(_ fwds: [VKReplyMessage]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(fwds) { fwd in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.tertiaryLabel))
                        .frame(width: 2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profiles[fwd.fromId]?.firstName ?? "Пересланное")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(msg.isOutgoing ? Color.white : Color(.label))
                            .lineLimit(1)
                        Text(fwd.text.isEmpty ? attachmentLabel(fwd.attachments) : fwd.text)
                            .font(.system(size: 14))
                            .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.85) : Color(.label))
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
                Image(systemName: "paperclip")
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.8) : tgAccent)
                Text(att.type)
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.7) : Color(.secondaryLabel))
            }
        }
    }

    // Photo
    @ViewBuilder
    func photoView(_ photo: VKPhoto?) -> some View {
        if let url = photo?.bestURL {
            let ratio = photo?.aspectRatio ?? 1.0
            let w: CGFloat = 240
            let h: CGFloat = min(300, max(80, w / ratio))
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFill()
                    .frame(maxWidth: w, maxHeight: h)
                    .clipped()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: w, height: h)
                    .overlay(ProgressView().tint(tgAccent))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // Video
    @ViewBuilder
    func videoView(_ video: VKVideo?) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let url = video?.thumbURL {
                CachedAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                        .frame(width: 240, height: 160).clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(width: 240, height: 160)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 240, height: 160)
            }
            // Play button
            Circle()
                .fill(Color.black.opacity(0.45))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "play.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 18))
                )
                .position(x: 120, y: 80)
            // Duration badge
            if let d = video?.durationFormatted, !d.isEmpty {
                Text(d)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(8)
            }
        }
        if let title = video?.title, !title.isEmpty {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(msg.isOutgoing ? Color.white : tgAccent)
                .lineLimit(2)
        }
    }

    // Voice message
    func voiceView(_ audio: VKAudioMessage?) -> some View {
        let url     = audio?.linkMp3 ?? audio?.linkOgg ?? ""
        let playing = audioPlayer.currentURL == url && audioPlayer.isPlaying

        return HStack(spacing: 10) {
            Button { audioPlayer.toggle(url: url) } label: {
                Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(msg.isOutgoing ? Color.white : tgAccent)
            }
            VStack(alignment: .leading, spacing: 4) {
                WaveformView(
                    waveform: audio?.waveform ?? [],
                    progress: audioPlayer.currentURL == url ? audioPlayer.progress : 0,
                    tint:     msg.isOutgoing ? Color.white : tgAccent
                )
                .frame(height: 22)
                .frame(maxWidth: 140)
                Text(formatDuration(audio?.duration ?? 0))
                    .font(.system(size: 12))
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.75) : Color(.secondaryLabel))
                    .monospacedDigit()
            }
        }
    }

    // Video message (circle / кружок)
    @ViewBuilder
    func videoMessageView(_ vmsg: VKVideoMessage?) -> some View {
        ZStack {
            if let url = vmsg?.previewURL {
                CachedAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color(.tertiarySystemBackground))
                        .frame(width: 200, height: 200)
                        .overlay(ProgressView().tint(tgAccent))
                }
            } else {
                Circle()
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "video.circle")
                            .font(.system(size: 44))
                            .foregroundStyle(Color(.secondaryLabel))
                    )
            }
            // Frosted play overlay
            Circle()
                .fill(Color.black.opacity(0.25))
                .frame(width: 200, height: 200)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.85))
                )
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 3) {
                if let d = vmsg?.duration {
                    Text(formatDuration(d))
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
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
                    .fill(tgAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: docIcon(doc?.ext))
                    .font(.system(size: 22))
                    .foregroundStyle(tgAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(doc?.displayTitle ?? "Документ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(msg.isOutgoing ? Color.white : Color(.label))
                    .lineLimit(1)
                Text("\(doc?.ext?.uppercased() ?? "") · \(doc?.sizeFormatted ?? "")")
                    .font(.system(size: 12))
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.7) : Color(.secondaryLabel))
            }
        }
    }

    // Audio track
    func audioView(_ audio: VKAudio?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 18))
                .foregroundStyle(msg.isOutgoing ? Color.white : tgAccent)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(msg.isOutgoing ? Color.white.opacity(0.15) : tgAccent.opacity(0.15))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(audio?.title ?? "Аудио")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(msg.isOutgoing ? Color.white : Color(.label))
                    .lineLimit(1)
                Text(audio?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.7) : Color(.secondaryLabel))
                    .lineLimit(1)
            }
            Spacer()
            Text(audio?.durationFormatted ?? "")
                .font(.system(size: 12))
                .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.7) : Color(.secondaryLabel))
                .monospacedDigit()
        }
    }

    // Link preview
    func linkView(_ link: VKLink?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let photo = link?.photo, let url = photo.thumbURL {
                CachedAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                        .frame(height: 120).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: { EmptyView() }
            }
            if let title = link?.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(msg.isOutgoing ? Color.white : tgAccent)
                    .lineLimit(2)
            }
            if let cap = link?.caption, !cap.isEmpty {
                Text(cap)
                    .font(.system(size: 12))
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.7) : Color(.secondaryLabel))
                    .lineLimit(1)
            }
        }
    }

    // Wall post
    func wallView(_ wall: VKWall?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.8) : tgAccent)
                Text("Запись на стене")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(msg.isOutgoing ? Color.white : tgAccent)
            }
            if let text = wall?.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.9) : Color(.label))
                    .lineLimit(4)
            }
        }
    }

    // Graffiti
    @ViewBuilder
    func graffitiView(_ graffiti: VKGraffiti?) -> some View {
        if let url = graffiti?.imageURL {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 200)
            } placeholder: { EmptyView() }
        }
    }

    // Gift
    @ViewBuilder
    func giftView(_ gift: VKGift?) -> some View {
        if let url = gift?.thumbURL {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFit()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } placeholder: { EmptyView() }
        } else {
            HStack {
                Image(systemName: "gift.fill").foregroundStyle(tgAccent)
                Text("Подарок").foregroundStyle(msg.isOutgoing ? Color.white : Color(.label))
            }
        }
    }

    // Poll
    func pollView(_ poll: VKPoll?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.8) : tgAccent)
                Text(poll?.question ?? "Опрос")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(msg.isOutgoing ? Color.white : Color(.label))
            }
            ForEach(poll?.answers ?? []) { answer in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(answer.text ?? "")
                            .font(.system(size: 13))
                            .foregroundStyle(msg.isOutgoing ? Color.white : Color(.label))
                        Spacer()
                        Text("\(answer.votes ?? 0)")
                            .font(.system(size: 12))
                            .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.7) : Color(.secondaryLabel))
                    }
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(msg.isOutgoing ? Color.white.opacity(0.4) : tgAccent.opacity(0.35))
                            .frame(width: g.size.width * (answer.rate ?? 0) / 100)
                    }
                    .frame(height: 3)
                }
            }
            Text("\(poll?.votes ?? 0) голосов")
                .font(.system(size: 12))
                .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.7) : Color(.secondaryLabel))
        }
    }

    // Sticker — transparent, no bubble background
    @ViewBuilder
    func stickerView(_ sticker: VKSticker) -> some View {
        if let url = sticker.bestURL {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFit()
                    .frame(width: 160, height: 160)
                    .allowsHitTesting(false)
            } placeholder: {
                Color.clear.frame(width: 160, height: 160)
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
        Color(hue: Double(abs(fromId) % 360) / 360.0, saturation: 0.6, brightness: 0.75)
    }

    func docIcon(_ ext: String?) -> String {
        switch ext?.lowercased() {
        case "pdf":                       return "doc.fill"
        case "doc", "docx":              return "doc.text.fill"
        case "xls", "xlsx":              return "tablecells.fill"
        case "zip", "rar", "7z":         return "archivebox.fill"
        case "mp3", "ogg", "wav":        return "music.note"
        case "mp4", "avi", "mkv", "mov": return "film.fill"
        case "jpg", "jpeg", "png", "gif": return "photo.fill"
        default:                          return "doc.fill"
        }
    }

    func formatDuration(_ d: Int) -> String {
        String(format: "%d:%02d", d / 60, d % 60)
    }
}

// MARK: - Waveform

struct WaveformView: View {
    let waveform: [Int]
    let progress: Double
    var tint: Color = tgAccent

    var body: some View {
        GeometryReader { g in
            let bars = normalizedBars(width: g.size.width)
            HStack(spacing: 1.5) {
                ForEach(Array(bars.enumerated()), id: \.offset) { i, h in
                    let filled = Double(i) / Double(max(bars.count - 1, 1)) <= progress
                    RoundedRectangle(cornerRadius: 1)
                        .fill(filled ? tint : tint.opacity(0.35))
                        .frame(width: 2.5, height: max(2, h * g.size.height))
                }
            }
            .frame(height: g.size.height, alignment: .center)
        }
    }

    private func normalizedBars(width: CGFloat) -> [CGFloat] {
        let count = max(1, Int(width / 4))
        guard !waveform.isEmpty else { return Array(repeating: 0.1, count: count) }
        let maxVal = CGFloat(waveform.max() ?? 1)
        return (0..<count).map { i in
            let idx = Int(Double(i) / Double(count) * Double(waveform.count))
            let val = idx < waveform.count ? CGFloat(waveform[idx]) / maxVal : 0.1
            return max(0.08, val)
        }
    }
}

// MARK: - Typing Dots

struct TypingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(.secondaryLabel))
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase == i ? 1.3 : 0.9)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                               value: phase)
            }
        }
        .onAppear { phase = 0 }
    }
}

// MARK: - Telegram-style Wallpaper

struct TGWallpaper: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                Color(.systemGroupedBackground)
                Canvas { ctx, size in
                    // Subtle soft blobs
                    let blobData: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                        (0.15, 0.1,  250, 0.06),
                        (0.8,  0.25, 300, 0.05),
                        (0.3,  0.6,  280, 0.05),
                        (0.7,  0.75, 260, 0.06),
                    ]
                    for (rx, ry, r, op) in blobData {
                        let center = CGPoint(x: size.width * rx, y: size.height * ry)
                        let rect   = CGRect(x: center.x - r, y: center.y - r,
                                           width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: rect),
                                 with: .color(tgAccent.opacity(op)))
                    }
                }
            }
        }
    }
}
