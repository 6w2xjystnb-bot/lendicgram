import SwiftUI
import AVKit

// MARK: - Photo Viewer (pinch-to-zoom, swipe to dismiss)

struct PhotoViewerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var opacity: Double = 1

    var body: some View {
        ZStack {
            Color.black.opacity(opacity).ignoresSafeArea()

            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { v in scale = lastScale * v }
                            .onEnded { v in
                                lastScale = max(1, lastScale * v)
                                scale = lastScale
                                if lastScale == 1 {
                                    withAnimation(.easeOut(duration: 0.2)) { offset = .zero }
                                    lastOffset = .zero
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { v in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: lastOffset.width + v.translation.width,
                                        height: lastOffset.height + v.translation.height
                                    )
                                } else {
                                    offset = CGSize(width: 0, height: v.translation.height)
                                    opacity = Double(max(0.4, 1 - abs(v.translation.height) / 400))
                                }
                            }
                            .onEnded { v in
                                if scale > 1 {
                                    lastOffset = offset
                                } else {
                                    if abs(v.translation.height) > 120 {
                                        dismiss()
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            offset = .zero; opacity = 1
                                        }
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if scale > 1 {
                                scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                            } else {
                                scale = 2.5; lastScale = 2.5
                            }
                        }
                    }
                    .onTapGesture(count: 1) { dismiss() }
            } placeholder: {
                ProgressView().tint(.white)
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Video Player (native AVPlayer)

struct VideoPlayerView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(.top, 8).padding(.leading, 16)
        }
        .onAppear {
            let p = AVPlayer(url: videoURL)
            p.play()
            player = p
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .statusBarHidden()
    }
}
