import Foundation
import Combine

final class AuthService {
    static let shared = AuthService()
    private init() {}

    struct LoginRequest: Encodable {
        let email: String
        let password: String
        let rememberMe: Bool
    }

    struct LoginResponse: Decodable {
        let user: User
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
    }

    struct RefreshRequest: Encodable {
        let refreshToken: String
    }

    struct RefreshResponse: Decodable {
        let accessToken: String
        let expiresIn: Int
    }

    func login(email: String, password: String, rememberMe: Bool = true) async throws -> User {
        let body = LoginRequest(email: email, password: password, rememberMe: rememberMe)
        let response: LoginResponse = try await APIClient.shared.request(.post("/auth/login", body: body))

        try KeychainManager.shared.save(response.accessToken, for: Constants.Keychain.accessTokenKey)
        try KeychainManager.shared.save(response.refreshToken, for: Constants.Keychain.refreshTokenKey)
        try KeychainManager.shared.save(String(response.user.id), for: Constants.Keychain.userIdKey)

        return response.user
    }

    func logout() async throws {
        try? await APIClient.shared.requestVoid(.post("/auth/logout", body: EmptyBody()))
        KeychainManager.shared.clearAll()
    }

    func refreshToken() async throws {
        guard let refreshToken = try? KeychainManager.shared.retrieve(for: Constants.Keychain.refreshTokenKey) else {
            throw APIError.unauthorized
        }
        let body = RefreshRequest(refreshToken: refreshToken)
        let response: RefreshResponse = try await APIClient.shared.request(.post("/auth/refresh", body: body))
        try KeychainManager.shared.save(response.accessToken, for: Constants.Keychain.accessTokenKey)
    }

    func fetchCurrentUser() async throws -> User {
        try await APIClient.shared.request(.get("/auth/me"))
    }

    var isLoggedIn: Bool {
        (try? KeychainManager.shared.retrieve(for: Constants.Keychain.accessTokenKey)) != nil
    }
}

struct EmptyBody: Encodable {}
