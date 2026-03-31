import AVFoundation
import Combine

@MainActor
final class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    @Published var isPlaying  = false
    @Published var currentURL: String?
    @Published var progress: Double = 0

    private var player: AVPlayer?
    private var observer: Any?

    func toggle(url: String) {
        if currentURL == url {
            if isPlaying { pause() } else { resume() }
        } else {
            play(url: url)
        }
    }

    func play(url: String) {
        stop()
        guard let audioURL = URL(string: url) else { return }
        let item = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: item)
        player?.play()
        isPlaying = true
        currentURL = url

        observer = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self = self,
                      let dur = self.player?.currentItem?.duration.seconds,
                      dur > 0, !dur.isNaN else { return }
                self.progress = time.seconds / dur
                if time.seconds >= dur - 0.1 { self.stop() }
            }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        player?.play()
        isPlaying = true
    }

    func stop() {
        if let obs = observer { player?.removeTimeObserver(obs); observer = nil }
        player?.pause()
        player = nil
        isPlaying = false
        currentURL = nil
        progress = 0
    }
}
