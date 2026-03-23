import Foundation

final class VKAPIService {
    static let shared = VKAPIService()
    private init() {}

    private var token: String { VKAuthService.shared.accessToken }

    // MARK: - Conversations

    func getConversations(count: Int = 100, offset: Int = 0) async throws -> VKConversationsResponse {
        try await get("messages.getConversations", [
            "count": "\(count)", "offset": "\(offset)",
            "extended": "1", "fields": "photo_100,online",
        ])
    }

    // MARK: - Messages

    func getHistory(peerId: Int, count: Int = 50, offset: Int = 0) async throws -> VKMessagesResponse {
        try await get("messages.getHistory", [
            "peer_id": "\(peerId)", "count": "\(count)", "offset": "\(offset)",
            "extended": "1", "fields": "photo_100",
        ])
    }

    func send(peerId: Int, text: String) async throws -> Int {
        try await get("messages.send", [
            "peer_id":   "\(peerId)",
            "message":   text,
            "random_id": "\(Int.random(in: 1...999_999_999))",
        ])
    }

    // MARK: - Users

    func getUsers(_ ids: [Int]) async throws -> [VKUser] {
        try await get("users.get", [
            "user_ids": ids.map(String.init).joined(separator: ","),
            "fields": "photo_100,online",
        ])
    }

    func getCurrentUser() async throws -> VKUser {
        let list: [VKUser] = try await get("users.get", ["fields": "photo_100,photo_50"])
        guard let u = list.first else { throw VKAPIError.emptyResponse }
        return u
    }

    // MARK: - Long Poll

    func getLongPollServer() async throws -> VKLongPollServer {
        try await get("messages.getLongPollServer", ["need_pts": "0", "lp_version": "3"])
    }

    // MARK: - Generic

    func get<T: Decodable>(_ method: String, _ params: [String: String]) async throws -> T {
        var c = URLComponents(string: "\(VKConfig.baseURL)/\(method)")!
        c.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "access_token", value: token),
               URLQueryItem(name: "v",            value: VKConfig.apiVersion)]
        guard let url = c.url else { throw VKAPIError.invalidURL }

        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw VKAPIError.httpError }

        if let err = try? JSONDecoder().decode(VKErrorResponse.self, from: data) {
            throw VKAPIError.apiError(code: err.error.errorCode, msg: err.error.errorMsg)
        }
        return try JSONDecoder().decode(VKResponse<T>.self, from: data).response
    }
}
