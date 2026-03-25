import SwiftUI
import AVFoundation
import PhotosUI

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Graphite Dark Theme Colors (dirty sketch style)

private let waOutgoing   = Color(red: 0.18, green: 0.18, blue: 0.19)   // #2d2d30 charcoal
private let waIncoming   = Color(red: 0.14, green: 0.14, blue: 0.15)   // #232326 dark graphite
private let waGreen      = Color(red: 0.56, green: 0.56, blue: 0.58)   // #8e8e93 gray accent
private let waCheckRead  = Color(red: 0.63, green: 0.63, blue: 0.65)   // #a0a0a5 light gray checks
private let waGray       = Color(red: 0.39, green: 0.39, blue: 0.40)   // #636366 muted gray
private let waInputField = Color(red: 0.17, green: 0.17, blue: 0.18)   // #2c2c2e graphite
private let waHeaderBg   = Color(red: 0.11, green: 0.11, blue: 0.12)   // #1c1c1e dark

// MARK: - Chat View

struct ChatView: View {
    let peerId:   Int
    let peerName: String

    @StateObject private var vm: ChatViewModel
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @StateObject private var recorder = AudioRecorderService.shared
    @State private var input         = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showStickers  = false
    @State private var showVideoRecorder = false

    init(peerId: Int, peerName: String) {
        self.peerId   = peerId
        self.peerName = peerName
        _vm = StateObject(wrappedValue: ChatViewModel(peerId: peerId, peerName: peerName))
    }

    var body: some View {
        ZStack {
            // Subtle wallpaper
            ChatBackgroundView().ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                if showStickers {
                    StickerKeyboardView(packs: vm.stickerPacks) { stickerId in
                        showStickers = false
                        Task { await vm.sendSticker(stickerId: stickerId) }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { chatToolbar }
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .tint(.white)
        .alert("Ошибка", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .task { await vm.load() }
        .onChange(of: pickerItems) { _, items in
            Task { await handlePickedItems(items) }
        }
        .fullScreenCover(isPresented: $showVideoRecorder) {
            VideoMessageRecorderView { fileURL in
                showVideoRecorder = false
                Task { await vm.sendVideoMessage(fileURL: fileURL) }
            } onCancel: {
                showVideoRecorder = false
            }
        }
    }

    // MARK: - Message List

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if vm.hasMore {
                        Button { Task { await vm.loadMore() } } label: {
                            if vm.isLoading {
                                ProgressView().tint(waGreen).padding()
                            } else {
                                Text("Загрузить ранее")
                                    .font(.system(size: 13))
                                    .foregroundStyle(waGreen)
                                    .padding(10)
                            }
                        }
                    } else if vm.isLoading {
                        ProgressView().tint(waGreen).padding()
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
                                showTail:    shouldShowTail(at: index),
                                audioPlayer: audioPlayer
                            )
                            .id(msg.id)
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if !vm.typingUserIds.isEmpty { typingBar }
                    inputBar
                }
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

    // Whether this message should show a bubble tail
    func shouldShowTail(at index: Int) -> Bool {
        let msgs = vm.messages
        guard index < msgs.count else { return true }
        if index == 0 { return true }
        let prev = msgs[index - 1]
        return prev.isOutgoing != msgs[index].isOutgoing || prev.isService
    }

    // MARK: - Date Separator

    func dateSeparator(_ ts: Int) -> some View {
        Text(ts.vkDateSeparator)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color.black.opacity(0.35), in: Capsule())
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
                .foregroundStyle(waGray)
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 4)
    }

    // MARK: - Input Bar

    private var hasText: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var inputBar: some View {
        ZStack {
            // ── Recording overlay ────────────────────────────────────
            if recorder.isRecording {
                recordingBar
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                normalInputBar
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
    }

    var normalInputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Paperclip — individual glass circle
            PhotosPicker(selection: $pickerItems,
                         maxSelectionCount: 10,
                         matching: .any(of: [.images, .videos])) {
                Image(systemName: "paperclip")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(waGray)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }

            // Text field + emoji button — individual glass capsule
            HStack(alignment: .bottom, spacing: 4) {
                TextField("Сообщение", text: $input, axis: .vertical)
                    .lineLimit(1...6)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .submitLabel(.return)
                    .padding(.vertical, 10)
                    .padding(.leading, 14)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { showStickers.toggle() }
                    if showStickers && vm.stickerPacks.isEmpty {
                        Task { await vm.loadStickers() }
                    }
                } label: {
                    Image(systemName: showStickers ? "keyboard" : "face.smiling")
                        .font(.system(size: 22))
                        .foregroundStyle(showStickers ? waGreen : waGray)
                        .padding(.bottom, 9)
                        .padding(.trailing, 12)
                }
            }
            .glassEffect(.regular.interactive(), in: .capsule)

            // Send / Mic — individual element
            if hasText {
                Button {
                    Task { await vm.send(text: input); input = "" }
                } label: {
                    Group {
                        if vm.isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(red: 0.40, green: 0.40, blue: 0.42)))
                }
                .disabled(vm.isSending)
            } else {
                Button {
                    recorder.start()
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(waGray)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Recording Bar

    var recordingBar: some View {
        HStack(spacing: 14) {
            // Cancel — individual glass circle
            Button {
                recorder.cancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular.interactive(), in: .circle)
            }

            // Waveform + duration — individual glass capsule
            HStack(spacing: 10) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .opacity(recorder.isRecording ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recorder.isRecording)

                Text(formatRecordingDuration(recorder.duration))
                    .font(.system(size: 17, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white)

                RecordingWaveformView(samples: recorder.waveformSamples)
                    .frame(height: 24)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)
            .frame(maxWidth: .infinity)

            // Send — green circle
            Button {
                if let result = recorder.stop() {
                    Task { await vm.sendVoice(fileURL: result.url) }
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color(red: 0.40, green: 0.40, blue: 0.42)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private func formatRecordingDuration(_ d: TimeInterval) -> String {
        let m = Int(d) / 60
        let s = Int(d) % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var chatToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(peerName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Group {
                    if !vm.typingUserIds.isEmpty {
                        Text("печатает...")
                            .foregroundStyle(tgOnline)
                    } else if let u = vm.peerUser {
                        Text(u.isOnline ? (u.isMobile ? "в сети с телефона" : "в сети") : u.statusText)
                            .foregroundStyle(u.isOnline ? tgOnline : waGray)
                    } else if vm.isGroupChat {
                        Text("беседа")
                            .foregroundStyle(waGray)
                    }
                }
                .font(.system(size: 13))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            VKAvatarView(url: vm.peerUser?.avatarURL, name: peerName, size: 34)
                .glassEffect(.regular.interactive(), in: .circle)
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
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color.black.opacity(0.35), in: Capsule())
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
    var showTail:    Bool = true
    let audioPlayer: AudioPlayerService

    @State private var selectedPhotoURL: URL?
    @State private var selectedVideoURL: URL?

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if msg.isOutgoing { Spacer(minLength: 60) }

            VStack(alignment: msg.isOutgoing ? .trailing : .leading, spacing: 2) {
                if showSender {
                    Text(profiles[msg.fromId]?.firstName ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(senderColor(msg.fromId))
                        .padding(.horizontal, 14)
                }
                bubble
            }
            .padding(msg.isOutgoing ? .trailing : .leading, 4)

            if !msg.isOutgoing { Spacer(minLength: 60) }
        }
        .padding(.vertical, 1)
        .fullScreenCover(item: $selectedPhotoURL) { url in
            PhotoViewerView(url: url)
        }
        .fullScreenCover(item: $selectedVideoURL) { url in
            VideoPlayerView(videoURL: url)
        }
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
                ZStack(alignment: .bottomTrailing) {
                    stickerView(att.sticker!)
                    timeAndCheck
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                        .padding(4)
                }
            } else if att.type == "video_message" {
                videoMessageView(att.videoMessage)
            } else if att.type == "photo" {
                VStack(spacing: 0) {
                    photoView(att.photo)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        timeAndCheck
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(bubbleColor))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            } else if att.type == "video" {
                VStack(spacing: 0) {
                    videoView(att.video)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        timeAndCheck
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(bubbleColor))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            }
        } else {
            let hasMedia = msg.attachments?.contains(where: { $0.type == "photo" || $0.type == "video" }) ?? false
            VStack(alignment: .leading, spacing: 0) {
                // Media attachments edge-to-edge at top
                if let atts = msg.attachments, !atts.isEmpty {
                    ForEach(Array(atts.enumerated()), id: \.offset) { _, att in
                        if att.type == "photo" || att.type == "video" {
                            attachmentView(att)
                        }
                    }
                }
                // Text content + non-media attachments below
                VStack(alignment: .leading, spacing: 6) {
                    if let reply = msg.replyMessage {
                        replyPreview(reply)
                    }
                    if let fwds = msg.fwdMessages, !fwds.isEmpty {
                        fwdPreview(fwds)
                    }
                    if let atts = msg.attachments, !atts.isEmpty {
                        ForEach(Array(atts.enumerated()), id: \.offset) { _, att in
                            if att.type != "photo" && att.type != "video" {
                                attachmentView(att)
                            }
                        }
                    }
                    if !msg.text.isEmpty || (msg.attachments == nil && msg.replyMessage == nil && (msg.fwdMessages ?? []).isEmpty) {
                        HStack(alignment: .bottom, spacing: 6) {
                            Text(msg.text.isEmpty ? " " : msg.text)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                            metaInfo
                        }
                    } else {
                        HStack(spacing: 0) { Spacer(minLength: 0); metaInfo }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
            }
            .frame(maxWidth: hasMedia ? 240 : .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: hasMedia ? 14 : 20).fill(bubbleColor))
            .clipShape(RoundedRectangle(cornerRadius: hasMedia ? 14 : 20))
            .overlay {
                if hasMedia {
                    RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
            }
        }
    }

    private var bubbleColor: Color {
        msg.isOutgoing ? waOutgoing : waIncoming
    }

    private var bubbleBg: some ShapeStyle {
        AnyShapeStyle(bubbleColor)
    }

    private var bubbleShape: some Shape {
        RoundedRectangle(cornerRadius: 16)
    }

    // MARK: - Meta

    var metaInfo: some View { timeAndCheck.padding(.bottom, 1) }

    var timeAndCheck: some View {
        HStack(spacing: 3) {
            if msg.isEdited {
                Text("ред.")
                    .font(.system(size: 10))
                    .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.6) : waGray)
            }
            Text(msg.date.vkTime)
                .font(.system(size: 11))
                .foregroundStyle(msg.isOutgoing ? Color.white.opacity(0.6) : waGray)
            if msg.isOutgoing {
                WADoubleCheck(isRead: isRead)
            }
        }
    }

    // MARK: - Reply

    func replyPreview(_ reply: VKReplyMessage) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(waGreen)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(profiles[reply.fromId]?.firstName ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(waGreen)
                    .lineLimit(1)
                Text(reply.text.isEmpty ? attachmentLabel(reply.attachments) : reply.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
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
                        .fill(waGreen)
                        .frame(width: 2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profiles[fwd.fromId]?.firstName ?? "Пересланное")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(waGreen)
                            .lineLimit(1)
                        Text(fwd.text.isEmpty ? attachmentLabel(fwd.attachments) : fwd.text)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.85))
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
                    .foregroundStyle(.white.opacity(0.7))
                Text(att.type)
                    .foregroundStyle(.white.opacity(0.5))
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
                    .frame(width: w, height: h)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(waIncoming)
                    .frame(width: w, height: h)
                    .overlay(ProgressView().tint(waGreen))
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedPhotoURL = url }
        }
    }

    // Video
    @ViewBuilder
    func videoView(_ video: VKVideo?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let url = video?.thumbURL {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                            .frame(width: 240, height: 160).clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(waIncoming)
                            .frame(width: 240, height: 160)
                    }
                } else {
                    Rectangle()
                        .fill(waIncoming)
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
            .contentShape(Rectangle())
            .onTapGesture {
                guard let vid = video?.id, let oid = video?.ownerId else { return }
                Task {
                    if let full = try? await VKAPIService.shared.getVideo(ownerId: oid, videoId: vid),
                       let url = full.bestFileURL {
                        selectedVideoURL = url
                    }
                }
            }
            if let title = video?.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(waGreen)
                    .lineLimit(2)
            }
        }
    }

    // Voice message — WhatsApp style
    func voiceView(_ audio: VKAudioMessage?) -> some View {
        let url     = audio?.linkMp3 ?? audio?.linkOgg ?? ""
        let playing = audioPlayer.currentURL == url && audioPlayer.isPlaying

        return HStack(spacing: 12) {
            Button { audioPlayer.toggle(url: url) } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.40, green: 0.40, blue: 0.42))
                        .frame(width: 52, height: 52)
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: playing ? 0 : 2)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                WaveformView(
                    waveform: audio?.waveform ?? [],
                    progress: audioPlayer.currentURL == url ? audioPlayer.progress : 0,
                    tint:     .white.opacity(0.7)
                )
                .frame(height: 28)
                .frame(maxWidth: .infinity)
                HStack(spacing: 4) {
                    Text(formatDuration(audio?.duration ?? 0))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }

    // Video message (circle / кружок) — with inline playback
    @ViewBuilder
    func videoMessageView(_ vmsg: VKVideoMessage?) -> some View {
        InlineVideoMessageView(
            videoMessage: vmsg,
            timeAndCheck: timeAndCheck,
            formatDuration: formatDuration
        )
    }

    // Document
    func docView(_ doc: VKDoc?) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(waGreen.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: docIcon(doc?.ext))
                    .font(.system(size: 22))
                    .foregroundStyle(waGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(doc?.displayTitle ?? "Документ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(doc?.ext?.uppercased() ?? "") · \(doc?.sizeFormatted ?? "")")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // Audio track
    func audioView(_ audio: VKAudio?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 18))
                .foregroundStyle(waGreen)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(waGreen.opacity(0.15))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(audio?.title ?? "Аудио")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(audio?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer()
            Text(audio?.durationFormatted ?? "")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
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
                    .foregroundStyle(waGreen)
                    .lineLimit(2)
            }
            if let cap = link?.caption, !cap.isEmpty {
                Text(cap)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
    }

    // Wall post
    func wallView(_ wall: VKWall?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(waGreen.opacity(0.9))
                Text("Запись на стене")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(waGreen)
            }
            if let text = wall?.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
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
                Image(systemName: "gift.fill").foregroundStyle(waGreen)
                Text("Подарок").foregroundStyle(.white)
            }
        }
    }

    // Poll
    func pollView(_ poll: VKPoll?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(waGreen.opacity(0.9))
                Text(poll?.question ?? "Опрос")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            ForEach(poll?.answers ?? []) { answer in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(answer.text ?? "")
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(answer.votes ?? 0)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(waGreen.opacity(0.35))
                            .frame(width: g.size.width * (answer.rate ?? 0) / 100)
                    }
                    .frame(height: 3)
                }
            }
            Text("\(poll?.votes ?? 0) голосов")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // Sticker — transparent, no bubble background, shadow for contrast
    @ViewBuilder
    func stickerView(_ sticker: VKSticker) -> some View {
        if let url = sticker.bestURL {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFit()
                    .frame(width: 160, height: 160)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
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
    var tint: Color = waGreen

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
                    .fill(waGray)
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase == i ? 1.3 : 0.9)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                               value: phase)
            }
        }
        .onAppear { phase = 0 }
    }
}

// MARK: - Inline Video Message Player

struct InlineVideoMessageView: View {
    let videoMessage: VKVideoMessage?
    let timeAndCheck: AnyView
    let formatDuration: (Int) -> String

    @State private var isPlaying = false
    @State private var player: AVPlayer?
    @State private var progress: Double = 0
    @State private var observer: Any?

    init(videoMessage: VKVideoMessage?,
         timeAndCheck: some View,
         formatDuration: @escaping (Int) -> String) {
        self.videoMessage = videoMessage
        self.timeAndCheck = AnyView(timeAndCheck)
        self.formatDuration = formatDuration
    }

    var body: some View {
        ZStack {
            if isPlaying, let player = player {
                VideoPlayerCircleView(player: player)
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
                    .onTapGesture { stopPlayback() }
            } else {
                // Preview thumbnail
                if let url = videoMessage?.previewURL {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(waIncoming)
                            .frame(width: 200, height: 200)
                            .overlay(ProgressView().tint(waGreen))
                    }
                } else {
                    Circle()
                        .fill(waIncoming)
                        .frame(width: 200, height: 200)
                        .overlay(
                            Image(systemName: "video.circle")
                                .font(.system(size: 44))
                                .foregroundStyle(waGray)
                        )
                }
                // Play button overlay
                Circle()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.85))
                    )
                    .onTapGesture { startPlayback() }
            }

            // Progress ring
            if isPlaying {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(red: 0.56, green: 0.56, blue: 0.58), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 3) {
                if let d = videoMessage?.duration {
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
        .onDisappear { stopPlayback() }
    }

    private func startPlayback() {
        guard let link = videoMessage?.link, let url = URL(string: link) else { return }
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer
        isPlaying = true
        avPlayer.play()

        observer = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { time in
            guard let dur = avPlayer.currentItem?.duration.seconds,
                  dur > 0, !dur.isNaN else { return }
            progress = time.seconds / dur
            if time.seconds >= dur - 0.1 { stopPlayback() }
        }
    }

    private func stopPlayback() {
        if let obs = observer { player?.removeTimeObserver(obs); observer = nil }
        player?.pause()
        player = nil
        isPlaying = false
        progress = 0
    }
}

// MARK: - Video Player Circle (UIViewRepresentable)

struct VideoPlayerCircleView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        context.coordinator.playerLayer = playerLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

// MARK: - Recording Waveform (live)

struct RecordingWaveformView: View {
    let samples: [Float]

    var body: some View {
        GeometryReader { g in
            let barCount = max(1, Int(g.size.width / 4))
            let displaySamples = recentSamples(count: barCount)
            HStack(spacing: 1.5) {
                ForEach(Array(displaySamples.enumerated()), id: \.offset) { _, h in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(waGreen)
                        .frame(width: 2.5, height: max(2, h * g.size.height))
                }
            }
            .frame(height: g.size.height, alignment: .center)
        }
    }

    private func recentSamples(count: Int) -> [CGFloat] {
        guard !samples.isEmpty else { return Array(repeating: 0.08, count: count) }
        // Take the last `count` samples
        let recent = samples.suffix(count)
        let maxAbs: Float = 60  // dB range
        return recent.map { sample in
            let normalized = (sample + maxAbs) / maxAbs
            return CGFloat(max(0.08, min(1.0, normalized)))
        }
    }
}

// MARK: - Telegram-style Wallpaper

struct TGWallpaper: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                Color(red: 0.09, green: 0.09, blue: 0.10)
                Canvas { ctx, size in
                    let blobData: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                        (0.15, 0.1,  250, 0.04),
                        (0.8,  0.25, 300, 0.03),
                        (0.3,  0.6,  280, 0.035),
                        (0.7,  0.75, 260, 0.04),
                    ]
                    for (rx, ry, r, op) in blobData {
                        let center = CGPoint(x: size.width * rx, y: size.height * ry)
                        let rect   = CGRect(x: center.x - r, y: center.y - r,
                                           width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: rect),
                                 with: .color(Color(red: 0.35, green: 0.35, blue: 0.38).opacity(op)))
                    }
                }
            }
        }
    }
}

// MARK: - WhatsApp Double Check (✓✓)

struct WADoubleCheck: View {
    let isRead: Bool

    var body: some View {
        HStack(spacing: -4) {
            Image(systemName: "checkmark")
            Image(systemName: "checkmark")
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(isRead ? waCheckRead : .white.opacity(0.55))
    }
}

// BubbleTailShape removed — bubbles are now simple rounded rects
