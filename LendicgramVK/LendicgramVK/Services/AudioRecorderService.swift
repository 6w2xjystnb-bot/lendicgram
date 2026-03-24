import AVFoundation
import Combine

@MainActor
final class AudioRecorderService: ObservableObject {
    static let shared = AudioRecorderService()
    private init() {}

    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var waveformSamples: [Float] = []

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private(set) var fileURL: URL?

    /// Start recording voice message (OGG not supported natively, use m4a then upload)
    func start() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch { return }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            fileURL = url
            isRecording = true
            duration = 0
            waveformSamples = []
            startTimer()
        } catch {}
    }

    /// Stop recording and return file URL + waveform data
    func stop() -> (url: URL, waveform: [Int], duration: Int)? {
        guard let recorder = recorder, isRecording else { return nil }
        recorder.stop()
        isRecording = false
        stopTimer()

        guard let url = fileURL else { return nil }
        let dur = Int(duration)
        // Convert float samples to VK-style 0-255 waveform
        let vkWaveform = waveformSamples.map { sample in
            Int(min(255, max(0, (sample + 60) / 60 * 255)))
        }
        self.recorder = nil
        return (url: url, waveform: vkWaveform, duration: dur)
    }

    func cancel() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        isRecording = false
        fileURL = nil
        duration = 0
        waveformSamples = []
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let rec = self.recorder, rec.isRecording else { return }
                self.duration = rec.currentTime
                rec.updateMeters()
                let power = rec.averagePower(forChannel: 0)
                self.waveformSamples.append(power)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
