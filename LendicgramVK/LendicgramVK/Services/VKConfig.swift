import Foundation

enum VKConfig {
    static let appId      = "54500817"
    static let apiVersion = "5.199"
    static let baseURL    = "https://api.vk.com/method"

    static let authURL: URL = {
        var c = URLComponents(string: "https://oauth.vk.com/authorize")!
        c.queryItems = [
            .init(name: "client_id",     value: appId),
            .init(name: "display",       value: "mobile"),
            .init(name: "redirect_uri",  value: "https://oauth.vk.com/blank.html"),
            .init(name: "scope",         value: "messages,friends,photos,offline"),
            .init(name: "response_type", value: "token"),
            .init(name: "v",             value: apiVersion),
        ]
        return c.url!
    }()
}
