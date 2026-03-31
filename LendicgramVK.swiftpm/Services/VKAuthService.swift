import Foundation
import Combine

final class VKAuthService: ObservableObject {
    static let shared = VKAuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUserId   = 0

    private(set) var accessToken: String = ""

    private init() {
        accessToken    = UserDefaults.standard.string(forKey: "vk_token")  ?? ""
        currentUserId  = UserDefaults.standard.integer(forKey: "vk_uid")
        isAuthenticated = !accessToken.isEmpty
    }

    func login(token: String, userId: Int) {
        accessToken   = token
        currentUserId = userId
        UserDefaults.standard.set(token,  forKey: "vk_token")
        UserDefaults.standard.set(userId, forKey: "vk_uid")
        isAuthenticated = true
    }

    func logout() {
        accessToken    = ""
        currentUserId  = 0
        UserDefaults.standard.removeObject(forKey: "vk_token")
        UserDefaults.standard.removeObject(forKey: "vk_uid")
        isAuthenticated = false
    }
}
