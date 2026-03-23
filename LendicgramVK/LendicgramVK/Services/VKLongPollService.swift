import Foundation
import Combine

@MainActor
final class VKLongPollService: ObservableObject {
    static let shared = VKLongPollService()
    private init() {}

    @Published var newMessage: VKAPIMessage? = nil

    private var server = ""
    private var key    = ""
    private var ts     = ""
    private var pollTask: Task<Void, Never>?

    func start() async {
        do {
            let lp = try await VKAPIService.shared.getLongPollServer()
            server = lp.server; key = lp.key; ts = lp.ts
            startLoop()
        } catch { print("[LongPoll] start error:", error) }
    }

    func stop() { pollTask?.cancel(); pollTask = nil }

    private func startLoop() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
            }
        }
    }

    private func poll() async {
        guard !server.isEmpty else { return }
        let urlStr = "https://\(server)?act=a_check&key=\(key)&ts=\(ts)&wait=25&mode=2&version=3"
        guard let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(VKLongPollResponse.self, from: data)

            if let failed = resp.failed {
                if failed == 1 { ts = resp.ts }
                else {
                    // Re-init long poll server
                    let lp = try await VKAPIService.shared.getLongPollServer()
                    server = lp.server; key = lp.key; ts = lp.ts
                }
                return
            }
            ts = resp.ts
            for update in resp.updates ?? [] { handle(update) }
        } catch {
            if !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func handle(_ u: [LPValue]) {
        guard let type = u.first?.intValue else { return }
        // Event 4 = new message
        guard type == 4, u.count >= 6 else { return }
        let msgId  = u[1].intValue ?? 0
        let flags  = u[2].intValue ?? 0
        let peerId = u[3].intValue ?? 0
        let ts     = u[4].intValue ?? 0
        let text   = u[5].stringValue ?? ""
        let isOut  = (flags & 2) != 0
        let msg = VKAPIMessage(
            id: msgId,
            fromId: isOut ? VKAuthService.shared.currentUserId : peerId,
            peerId: peerId,
            text: text,
            date: ts,
            out: isOut ? 1 : 0,
            attachments: nil
        )
        newMessage = msg
    }
}
