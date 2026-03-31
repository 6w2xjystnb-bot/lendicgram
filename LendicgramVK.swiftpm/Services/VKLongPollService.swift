import Foundation
import Combine

@MainActor
final class VKLongPollService: ObservableObject {
    static let shared = VKLongPollService()
    private init() {}

    // Events — PassthroughSubject guarantees no dropped events under rapid fire
    let newMessageSubject = PassthroughSubject<VKAPIMessage, Never>()
    let readSubject       = PassthroughSubject<(peerId: Int, msgId: Int), Never>()
    let readInSubject     = PassthroughSubject<(peerId: Int, msgId: Int), Never>()
    let onlineSubject     = PassthroughSubject<(userId: Int, online: Bool, platform: Int), Never>()
    let typingSubject     = PassthroughSubject<(userId: Int, peerId: Int), Never>()

    private var server = ""
    private var key    = ""
    private var ts     = ""
    private var pollTask: Task<Void, Never>?
    private var retryDelay: UInt64 = 1  // exponential backoff seconds

    var isRunning: Bool { pollTask != nil && !(pollTask?.isCancelled ?? true) }

    func start() async {
        guard !isRunning else { return }
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
        // mode: 2 (attachments) + 8 (extended) + 32 (pts) + 64 (online) + 128 (random_id) = 234
        let urlStr = "https://\(server)?act=a_check&key=\(key)&ts=\(ts)&wait=25&mode=234&version=3"
        guard let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(VKLongPollResponse.self, from: data)

            if let failed = resp.failed {
                if failed == 1 { ts = resp.ts }
                else {
                    let lp = try await VKAPIService.shared.getLongPollServer()
                    server = lp.server; key = lp.key; ts = lp.ts
                }
                return
            }
            retryDelay = 1  // reset backoff on success
            ts = resp.ts
            for update in resp.updates ?? [] { handle(update) }
        } catch {
            if !Task.isCancelled {
                try? await Task.sleep(for: .seconds(retryDelay))
                retryDelay = min(retryDelay * 2, 30)  // cap at 30s
            }
        }
    }

    private func handle(_ u: [LPValue]) {
        guard let type = u.first?.intValue else { return }

        switch type {

        // Event 4: new message
        case 4:
            guard u.count >= 6 else { return }
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
                attachments: nil,
                replyMessage: nil,
                fwdMessages: nil,
                action: nil,
                updateTime: nil,
                important: nil
            )
            newMessageSubject.send(msg)

        // Event 6: read incoming messages (we read their messages)
        case 6:
            guard u.count >= 3 else { return }
            let peerId  = u[1].intValue ?? 0
            let localId = u[2].intValue ?? 0
            readInSubject.send((peerId: peerId, msgId: localId))

        // Event 7: read outgoing messages (they read our messages)
        case 7:
            guard u.count >= 3 else { return }
            let peerId  = u[1].intValue ?? 0
            let localId = u[2].intValue ?? 0
            readSubject.send((peerId: peerId, msgId: localId))

        // Event 8: friend online
        case 8:
            guard u.count >= 3 else { return }
            let userId   = -(u[1].intValue ?? 0)
            let platform = u[2].intValue ?? 0
            onlineSubject.send((userId: userId, online: true, platform: platform))

        // Event 9: friend offline
        case 9:
            guard u.count >= 2 else { return }
            let userId = -(u[1].intValue ?? 0)
            onlineSubject.send((userId: userId, online: false, platform: 0))

        // Event 61: typing in dialog
        case 61:
            guard u.count >= 2 else { return }
            let userId = u[1].intValue ?? 0
            typingSubject.send((userId: userId, peerId: userId))

        // Event 62: typing in chat
        case 62:
            guard u.count >= 3 else { return }
            let peerId = u[1].intValue ?? 0
            let userId = u[2].intValue ?? 0
            typingSubject.send((userId: userId, peerId: peerId))

        default:
            break
        }
    }
}
