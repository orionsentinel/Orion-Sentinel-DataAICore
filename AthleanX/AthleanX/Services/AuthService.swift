import Foundation
import WebKit

final class AuthService {
    static let shared = AuthService()
    private init() {}

    // MARK: - Login (portal cookie auth — no REST API)

    func login(email: String, password: String) async throws {
        let cookies = try await PortalAuthBridge.shared.authenticate(email: email, password: password)

        // Persist a marker so we know the user is logged in across launches
        let cookieNames = cookies.map { $0.name }.joined(separator: ",")
        try KeychainManager.shared.save(cookieNames, for: Constants.Keychain.accessTokenKey)
        try KeychainManager.shared.save(email, for: Constants.Keychain.userIdKey)
    }

    func logout() async {
        PortalAuthBridge.shared.clearSession()
        KeychainManager.shared.clearAll()
    }

    func restoreSession() async -> Bool {
        guard KeychainManager.shared.hasValue(for: Constants.Keychain.accessTokenKey) else {
            return false
        }
        return await PortalAuthBridge.shared.restoreSession()
    }

    var savedEmail: String? {
        try? KeychainManager.shared.retrieve(for: Constants.Keychain.userIdKey)
    }
}
