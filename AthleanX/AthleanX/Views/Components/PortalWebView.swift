import SwiftUI
import WebKit

/// Full-screen authenticated WKWebView wrapper for portal.athleanx.com.
/// Serves as a fallback when native API data isn't available, and as a
/// bridge for portal features not yet surfaced natively (e.g. video courses,
/// program PDFs, member forum).
struct PortalWebView: UIViewRepresentable {
    let path: String
    var onNavigation: ((URL) -> Void)?

    init(path: String = "/", onNavigation: ((URL) -> Void)? = nil) {
        self.path = path
        self.onNavigation = onNavigation
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigation: onNavigation)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor(Constants.Colors.athleanDark)
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: Constants.API.portalBaseURL + path) else { return }
        if uiView.url?.path != url.path {
            var request = URLRequest(url: url)
            if let token = try? KeychainManager.shared.retrieve(for: Constants.Keychain.accessTokenKey) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            uiView.load(request)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onNavigation: ((URL) -> Void)?
        init(onNavigation: ((URL) -> Void)?) { self.onNavigation = onNavigation }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectDarkModeCSS(into: webView)
            hideMobilePromptBanner(in: webView)
            if let url = webView.url { onNavigation?(url) }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            // Open external links (App Store, social) in Safari instead
            if let host = url.host, !host.contains("athleanx.com") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        private func injectDarkModeCSS(into webView: WKWebView) {
            let css = """
            :root { color-scheme: dark; }
            body { background-color: #121212 !important; color: #fff !important; }
            """
            let js = """
            var style = document.getElementById('athleanx-native-overrides');
            if (!style) {
                style = document.createElement('style');
                style.id = 'athleanx-native-overrides';
                document.head.appendChild(style);
            }
            style.textContent = `\(css)`;
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func hideMobilePromptBanner(in webView: WKWebView) {
            // Hide any "download our app" banners since we ARE the app
            let js = """
            document.querySelectorAll('[class*="app-banner"], [class*="mobile-prompt"], [id*="app-install"]')
                .forEach(el => el.style.display = 'none');
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

/// Standalone screen presenting the full portal in a navigation context.
struct PortalScreenView: View {
    let title: String
    let path: String

    init(title: String = "Portal", path: String = "/dashboard") {
        self.title = title
        self.path = path
    }

    var body: some View {
        PortalWebView(path: path)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
