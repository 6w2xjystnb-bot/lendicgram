import Foundation

final class VKAPIService {
    static let shared = VKAPIService()
    private init() {}

    private var token: String { VKAuthService.shared.accessToken }

    // MARK: - Conversations

    func getConversations(count: Int = 100, offset: Int = 0) async throws -> VKConversationsResponse {
        try await get("messages.getConversations", [
            "count": "\(count)", "offset": "\(offset)",
            "extended": "1", "fields": "photo_100,photo_50,online,online_mobile,last_seen,sex",
        ])
    }

    func getConversationsById(peerIds: [Int]) async throws -> VKConversationsByIdResponse {
        try await get("messages.getConversationsById", [
            "peer_ids": peerIds.map(String.init).joined(separator: ","),
            "extended": "1", "fields": "photo_100,online,last_seen,sex",
        ])
    }

    // MARK: - Messages

    func getHistory(peerId: Int, count: Int = 50, offset: Int = 0) async throws -> VKMessagesResponse {
        try await get("messages.getHistory", [
            "peer_id": "\(peerId)", "count": "\(count)", "offset": "\(offset)",
            "extended": "1", "fields": "photo_100,online,online_mobile,last_seen,sex",
        ])
    }

    func getById(messageIds: [Int]) async throws -> VKMessagesResponse {
        try await get("messages.getById", [
            "message_ids": messageIds.map(String.init).joined(separator: ","),
            "extended": "1", "fields": "photo_100,online,last_seen,sex",
        ])
    }

    func send(peerId: Int, text: String, replyTo: Int? = nil) async throws -> Int {
        var params: [String: String] = [
            "peer_id":   "\(peerId)",
            "message":   text,
            "random_id": "\(Int.random(in: 1...999_999_999))",
        ]
        if let r = replyTo { params["reply_to"] = "\(r)" }
        return try await get("messages.send", params)
    }

    func markAsRead(peerId: Int) async throws {
        let _: Int = try await get("messages.markAsRead", [
            "peer_id": "\(peerId)",
        ])
    }

    func setActivity(peerId: Int, type: String = "typing") async throws {
        let _: Int = try await get("messages.setActivity", [
            "peer_id": "\(peerId)", "type": type,
        ])
    }

    func deleteMessage(messageIds: [Int], deleteForAll: Bool = true) async throws {
        let _: [String: Int] = try await get("messages.delete", [
            "message_ids": messageIds.map(String.init).joined(separator: ","),
            "delete_for_all": deleteForAll ? "1" : "0",
        ])
    }

    func editMessage(peerId: Int, messageId: Int, text: String) async throws {
        let _: Int = try await get("messages.edit", [
            "peer_id": "\(peerId)", "message_id": "\(messageId)", "message": text,
        ])
    }

    // MARK: - Users

    func getUsers(_ ids: [Int]) async throws -> [VKUser] {
        try await get("users.get", [
            "user_ids": ids.map(String.init).joined(separator: ","),
            "fields": "photo_100,photo_50,online,online_mobile,last_seen,sex",
        ])
    }

    func getCurrentUser() async throws -> VKUser {
        let list: [VKUser] = try await get("users.get", [
            "fields": "photo_100,photo_50,photo_200,online,online_mobile,last_seen,sex"
        ])
        guard let u = list.first else { throw VKAPIError.emptyResponse }
        return u
    }

    // MARK: - Friends

    func getFriends(count: Int = 500, offset: Int = 0, order: String = "hints") async throws -> VKFriendsResponse {
        try await get("friends.get", [
            "count": "\(count)", "offset": "\(offset)", "order": order,
            "fields": "photo_100,photo_50,online,online_mobile,last_seen,sex",
        ])
    }

    // MARK: - Photo Upload

    private struct UploadServerResponse: Decodable {
        let uploadUrl: String
        enum CodingKeys: String, CodingKey { case uploadUrl = "upload_url" }
    }

    private struct PhotoUploadResult: Decodable {
        let server: Int
        let photo: String
        let hash: String
    }

    /// Full pipeline: get upload URL → multipart upload → save → return attachment string
    func uploadPhotoForMessage(peerId: Int, imageData: Data) async throws -> String {
        // 1. Get upload server
        let serverResp: UploadServerResponse = try await get(
            "photos.getMessagesUploadServer", ["peer_id": "\(peerId)"])

        guard let uploadURL = URL(string: serverResp.uploadUrl) else {
            throw VKAPIError.invalidURL
        }

        // 2. Multipart upload
        let boundary = "VK-\(UUID().uuidString)"
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        var body = Data()
        let nl = "\r\n".data(using: .utf8)!
        body += "--\(boundary)\r\n".data(using: .utf8)!
        body += "Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!
        body += "Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!
        body += imageData
        body += nl
        body += "--\(boundary)--\r\n".data(using: .utf8)!

        let (uploadData, _) = try await URLSession.shared.upload(for: request, from: body)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let uploadResult = try decoder.decode(PhotoUploadResult.self, from: uploadData)

        // 3. Save photo
        let saved: [VKPhoto] = try await get("photos.saveMessagesPhoto", [
            "server": "\(uploadResult.server)",
            "photo":  uploadResult.photo,
            "hash":   uploadResult.hash,
        ])

        guard let photo = saved.first,
              let photoId  = photo.id,
              let ownerId  = photo.ownerId else {
            throw VKAPIError.emptyResponse
        }
        return "photo\(ownerId)_\(photoId)"
    }

    func sendWithAttachment(peerId: Int, text: String, attachment: String) async throws -> Int {
        try await get("messages.send", [
            "peer_id":   "\(peerId)",
            "message":   text,
            "attachment": attachment,
            "random_id": "\(Int.random(in: 1...999_999_999))",
        ])
    }

    // MARK: - Stickers

    func sendSticker(peerId: Int, stickerId: Int) async throws -> Int {
        try await get("messages.send", [
            "peer_id":    "\(peerId)",
            "sticker_id": "\(stickerId)",
            "random_id":  "\(Int.random(in: 1...999_999_999))",
        ])
    }

    func getStickersProducts() async throws -> VKStickersResponse {
        try await get("store.getProducts", [
            "type": "stickers",
            "filters": "active",
            "extended": "1",
        ])
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
