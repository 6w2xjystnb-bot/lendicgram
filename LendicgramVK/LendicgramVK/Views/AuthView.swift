import SwiftUI
import WebKit

// MARK: - Auth Screen

struct AuthView: View {
    @ObservedObject private var auth = VKAuthService.shared
    @State private var showWeb = false

    private let accent = Color(red: 0.35, green: 0.80, blue: 0.52)
    private let bg     = Color(red: 0.07, green: 0.10, blue: 0.07)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "message.fill")
                    .font(.system(size: 72))
                    .foregroundColor(accent)
                VStack(spacing: 8) {
                    Text("Lendicgram").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                    Text("Войдите через аккаунт ВКонтакте").font(.system(size: 16)).foregroundColor(Color(white: 0.5))
                }
                Spacer()
                Button {
                    showWeb = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill.badge.plus")
                        Text("Войти через VK")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(Color(white: 0.05))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(accent))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showWeb) {
            VKWebAuthSheet()
        }
    }
}

// MARK: - OAuth WebView sheet

struct VKWebAuthSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VKWebView { token, userId in
                VKAuthService.shared.login(token: token, userId: userId)
                dismiss()
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Вход в ВКонтакте")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }.foregroundColor(Color(red: 0.35, green: 0.80, blue: 0.52))
                }
            }
        }
    }
}

// MARK: - WKWebView wrapper

struct VKWebView: UIViewRepresentable {
    let onToken: (String, Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken) }

    func makeUIView(context: Context) -> WKWebView {
        let config    = WKWebViewConfiguration()
        let webView   = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor    = UIColor(red: 0.07, green: 0.10, blue: 0.07, alpha: 1)
        webView.scrollView.backgroundColor = .clear
        webView.load(URLRequest(url: VKConfig.authURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onToken: (String, Int) -> Void
        init(onToken: @escaping (String, Int) -> Void) { self.onToken = onToken }

        func webView(_ webView: WKWebView,
                     didFinish navigation: WKNavigation!) {
            // VK puts access_token in the URL fragment (#access_token=...)
            // WKWebView doesn't expose it directly, so we read it via JS
            webView.evaluateJavaScript("window.location.href") { [weak self] result, _ in
                guard let url = result as? String else { return }
                self?.tryExtract(from: url, webView: webView)
            }
        }

        private func tryExtract(from urlString: String, webView: WKWebView) {
            // Fragment approach first
            if let frag = URL(string: urlString)?.fragment, frag.contains("access_token") {
                parse(fragment: frag)
                return
            }
            // Some VK flows put params in query string after redirect
            if urlString.contains("access_token=") {
                let raw = urlString.components(separatedBy: "#").last
                    ?? urlString.components(separatedBy: "?").last ?? ""
                parse(fragment: raw)
                return
            }
            // Hash is only accessible via JS on blank.html
            if urlString.contains("blank.html") {
                webView.evaluateJavaScript("window.location.hash") { [weak self] res, _ in
                    if let hash = res as? String {
                        let clean = hash.hasPrefix("#") ? String(hash.dropFirst()) : hash
                        self?.parse(fragment: clean)
                    }
                }
            }
        }

        private func parse(fragment: String) {
            var params: [String: String] = [:]
            for pair in fragment.components(separatedBy: "&") {
                let kv = pair.components(separatedBy: "=")
                if kv.count == 2 { params[kv[0]] = kv[1] }
            }
            guard let token = params["access_token"],
                  let uidStr = params["user_id"],
                  let uid = Int(uidStr) else { return }
            DispatchQueue.main.async { self.onToken(token, uid) }
        }
    }
}
