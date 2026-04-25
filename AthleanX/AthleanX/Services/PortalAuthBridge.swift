import WebKit
import Foundation

/// Authenticates against portal.athleanx.com using a hidden WKWebView.
/// Injects credentials via JavaScript, monitors for a successful redirect,
/// then extracts session cookies for use across all portal content loads.
@MainActor
final class PortalAuthBridge: NSObject {
    static let shared = PortalAuthBridge()

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<[HTTPCookie], Error>?
    private var pendingEmail = ""
    private var pendingPassword = ""
    private var loginPageLoaded = false
    private var authAttemptCount = 0

    private let portalLoginURL = "https://portal.athleanx.com/login"
    private let successPathPrefixes = ["/dashboard", "/home", "/programs", "/my-programs",
                                        "/members", "/portal", "/workouts"]
    private let maxAuthAttempts = 3

    private override init() {}

    // MARK: - Public

    func authenticate(email: String, password: String) async throws -> [HTTPCookie] {
        pendingEmail = email
        pendingPassword = password
        loginPageLoaded = false
        authAttemptCount = 0

        let wv = makeWebView()
        self.webView = wv

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.continuation = continuation
            guard let url = URL(string: self?.portalLoginURL ?? "") else {
                continuation.resume(throwing: PortalAuthError.invalidURL)
                return
            }
            wv.load(URLRequest(url: url))
        }
    }

    func clearSession() {
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                         modifiedSince: .distantPast) { }
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        try? KeychainManager.shared.delete(for: Constants.Keychain.accessTokenKey)
    }

    func isSessionValid() async -> Bool {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        return cookies.contains { $0.domain.contains("athleanx.com") && !$0.isSessionOnly }
    }

    func restoreSession() async -> Bool {
        guard await isSessionValid() else { return false }
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        syncCookiesToURLSession(cookies)
        return true
    }

    // MARK: - Private

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.allowsInlineMediaPlayback = false
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.isHidden = true
        return wv
    }

    private func injectCredentials() {
        let js = """
        (function() {
            // React/Vue-compatible input fill
            function fillReactInput(el, value) {
                const descriptor = Object.getOwnPropertyDescriptor(
                    window.HTMLInputElement.prototype, 'value'
                );
                if (descriptor && descriptor.set) {
                    descriptor.set.call(el, value);
                } else {
                    el.value = value;
                }
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
                el.dispatchEvent(new Event('blur', { bubbles: true }));
            }

            var emailSelectors = [
                'input[type="email"]',
                'input[name="email"]',
                'input[name="username"]',
                'input[id*="email"]',
                'input[placeholder*="email" i]',
                'input[autocomplete="email"]'
            ];
            var passwordSelectors = [
                'input[type="password"]',
                'input[name="password"]',
                'input[id*="password"]',
                'input[autocomplete="current-password"]'
            ];

            var emailInput = null;
            for (var i = 0; i < emailSelectors.length; i++) {
                emailInput = document.querySelector(emailSelectors[i]);
                if (emailInput) break;
            }
            var passwordInput = null;
            for (var j = 0; j < passwordSelectors.length; j++) {
                passwordInput = document.querySelector(passwordSelectors[j]);
                if (passwordInput) break;
            }

            if (!emailInput || !passwordInput) {
                return JSON.stringify({ success: false, reason: "fields_not_found" });
            }

            fillReactInput(emailInput, "\(pendingEmail.jsEscaped)");
            fillReactInput(passwordInput, "\(pendingPassword.jsEscaped)");

            // Focus email first (some forms validate on focus)
            emailInput.focus();
            passwordInput.focus();

            // Find and click submit
            var submitButton = document.querySelector(
                'button[type="submit"], input[type="submit"], button:contains("Sign In"), [data-testid*="submit"], [class*="login-btn"], [class*="signin"]'
            );
            if (!submitButton) {
                var buttons = document.querySelectorAll('button');
                for (var k = 0; k < buttons.length; k++) {
                    var text = buttons[k].textContent.toLowerCase().trim();
                    if (text === "sign in" || text === "login" || text === "log in" || text === "submit") {
                        submitButton = buttons[k];
                        break;
                    }
                }
            }
            if (!submitButton) {
                var form = document.querySelector('form');
                if (form) { form.submit(); return JSON.stringify({ success: true, method: "form_submit" }); }
                return JSON.stringify({ success: false, reason: "no_submit" });
            }
            submitButton.click();
            return JSON.stringify({ success: true, method: "button_click" });
        })();
        """
        webView?.evaluateJavaScript(js) { result, error in
            if let resultStr = result as? String {
                print("[PortalAuthBridge] inject result: \(resultStr)")
            }
        }
    }

    private func extractAndFinish() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            let portalCookies = cookies.filter { $0.domain.contains("athleanx.com") }
            if portalCookies.isEmpty {
                self.continuation?.resume(throwing: PortalAuthError.noCookiesExtracted)
            } else {
                self.syncCookiesToURLSession(portalCookies)
                self.continuation?.resume(returning: portalCookies)
            }
            self.continuation = nil
            self.webView = nil
        }
    }

    private func syncCookiesToURLSession(_ cookies: [HTTPCookie]) {
        for cookie in cookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    private func isSuccessURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        return successPathPrefixes.contains(where: { path.hasPrefix($0) })
    }

    private func isLoginURL(_ url: URL) -> Bool {
        url.path.lowercased().contains("login") || url.path == "/"
    }
}

// MARK: - WKNavigationDelegate

extension PortalAuthBridge: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard let url = webView.url else { return }

            if isSuccessURL(url) {
                extractAndFinish()
                return
            }

            if isLoginURL(url) && !loginPageLoaded {
                loginPageLoaded = true
                try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s for JS framework to settle
                injectCredentials()
                return
            }

            if isLoginURL(url) && loginPageLoaded {
                authAttemptCount += 1
                if authAttemptCount >= maxAuthAttempts {
                    continuation?.resume(throwing: PortalAuthError.invalidCredentials)
                    continuation = nil
                    self.webView = nil
                }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in
            if let url = webView.url, isSuccessURL(url) {
                extractAndFinish()
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            continuation?.resume(throwing: PortalAuthError.networkError(error))
            continuation = nil
            self.webView = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFailProvisionalNavigation navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            continuation?.resume(throwing: PortalAuthError.networkError(error))
            continuation = nil
            self.webView = nil
        }
    }
}

// MARK: - Error types

enum PortalAuthError: LocalizedError {
    case invalidURL
    case invalidCredentials
    case noCookiesExtracted
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid portal URL."
        case .invalidCredentials: return "Incorrect email or password. Please try again."
        case .noCookiesExtracted: return "Login succeeded but session could not be saved."
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .timeout: return "Login timed out. Please check your connection."
        }
    }
}

// MARK: - String extension

private extension String {
    var jsEscaped: String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
