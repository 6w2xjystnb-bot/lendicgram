import SwiftUI
import WebKit

// MARK: - Auth Screen

struct AuthView: View {
    @ObservedObject private var auth = VKAuthService.shared
    @State private var showWeb = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + title
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(tgAccent.gradient)
                            .frame(width: 96, height: 96)
                        Image(systemName: "message.fill")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    VStack(spacing: 6) {
                        Text("Lendicgram")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Color(.label))
                        Text("Мессенджер для ВКонтакте")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }

                Spacer()

                // Login button
                VStack(spacing: 12) {
                    Button {
                        showWeb = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill.badge.plus")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Войти через VK")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(tgAccent, in: Capsule())
                    }
                    .padding(.horizontal, 32)

                    Text("Нажимая «Войти», вы соглашаетесь с условиями использования")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 52)
            }
        }
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
                    Button("Отмена") { dismiss() }.tint(tgAccent)
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
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: VKConfig.authURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onToken: (String, Int) -> Void
        init(onToken: @escaping (String, Int) -> Void) { self.onToken = onToken }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("window.location.href") { [weak self] result, _ in
                guard let url = result as? String else { return }
                self?.tryExtract(from: url, webView: webView)
            }
        }

        private func tryExtract(from urlString: String, webView: WKWebView) {
            if let frag = URL(string: urlString)?.fragment, frag.contains("access_token") {
                parse(fragment: frag); return
            }
            if urlString.contains("access_token=") {
                let raw = urlString.components(separatedBy: "#").last
                    ?? urlString.components(separatedBy: "?").last ?? ""
                parse(fragment: raw); return
            }
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
