import SwiftUI
import AVFoundation

// MARK: - Video Message Recorder View

struct VideoMessageRecorderView: View {
    let onSend: (URL) -> Void
    let onCancel: () -> Void

    @StateObject private var camera = VideoRecorderController()
    @State private var isRecording = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    private let maxDuration: TimeInterval = 60

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera preview — circular
            CameraPreviewView(session: camera.session)
                .frame(width: 280, height: 280)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(isRecording ? Color.red : Color.white.opacity(0.5), lineWidth: 3)
                )
                .overlay(
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: min(1, elapsed / maxDuration))
                        .stroke(tgAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: elapsed)
                )

            VStack {
                // Top bar — close + timer
                HStack {
                    Button { cancel() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    Spacer()
                    if isRecording {
                        HStack(spacing: 6) {
                            Circle().fill(.red).frame(width: 8, height: 8)
                            Text(formatTime(elapsed))
                                .font(.system(size: 15, weight: .medium).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                    Spacer()
                    // Flip camera
                    Button { camera.flipCamera() } label: {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Bottom — record / stop+send
                HStack(spacing: 40) {
                    if isRecording {
                        // Stop & send
                        Button { stopAndSend() } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(tgAccent)
                        }
                    } else {
                        // Record
                        Button { startRecording() } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 64, height: 64)
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 72, height: 72)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { camera.configure() }
        .onDisappear { cleanup() }
    }

    private func startRecording() {
        camera.startRecording()
        isRecording = true
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 0.1
                if elapsed >= maxDuration { stopAndSend() }
            }
        }
    }

    private func stopAndSend() {
        timer?.invalidate()
        timer = nil
        isRecording = false
        camera.stopRecording { url in
            if let url = url {
                onSend(url)
            }
        }
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
        if isRecording {
            camera.stopRecording { _ in }
        }
        isRecording = false
        onCancel()
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        camera.stop()
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraContainerView {
        let view = CameraContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraContainerView, context: Context) {
        uiView.previewLayer.session = session
    }

    class CameraContainerView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Video Recorder Controller

@MainActor
final class VideoRecorderController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var output = AVCaptureMovieFileOutput()
    private var currentCamera: AVCaptureDevice.Position = .front
    private var completion: ((URL?) -> Void)?
    private var tempURL: URL?

    func configure() {
        session.beginConfiguration()
        session.sessionPreset = .medium

        // Audio input
        if let mic = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Video input
        addCamera(.front)

        // Output
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
        Task.detached { [session] in session.startRunning() }
    }

    private func addCamera(_ position: AVCaptureDevice.Position) {
        // Remove existing video inputs
        for input in session.inputs {
            if let devInput = input as? AVCaptureDeviceInput, devInput.device.hasMediaType(.video) {
                session.removeInput(devInput)
            }
        }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }
        session.addInput(input)
        currentCamera = position
    }

    func flipCamera() {
        session.beginConfiguration()
        addCamera(currentCamera == .front ? .back : .front)
        session.commitConfiguration()
    }

    func startRecording() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("video_msg_\(UUID().uuidString).mp4")
        tempURL = url
        output.startRecording(to: url, recordingDelegate: self)
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        if output.isRecording {
            output.stopRecording()
        } else {
            completion(nil)
        }
    }

    func stop() {
        if output.isRecording { output.stopRecording() }
        session.stopRunning()
    }
}

extension VideoRecorderController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection], error: (any Error)?) {
        Task { @MainActor in
            completion?(error == nil ? outputFileURL : nil)
            completion = nil
        }
    }
}
