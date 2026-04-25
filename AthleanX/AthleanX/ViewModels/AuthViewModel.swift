import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var isCheckingSession = true
    @Published var errorMessage: String?

    @Published var email = ""
    @Published var password = ""
    @Published var rememberMe = true

    private let authService = AuthService.shared

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Session restore

    private func restoreSession() async {
        isCheckingSession = true
        if rememberMe || UserDefaults.standard.bool(forKey: "rememberMe") {
            isAuthenticated = await authService.restoreSession()
        }
        if let saved = authService.savedEmail, !saved.isEmpty {
            email = saved
        }
        isCheckingSession = false
    }

    // MARK: - Login

    func login() async {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }
        guard email.isValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.login(email: email, password: password)
            UserDefaults.standard.set(rememberMe, forKey: "rememberMe")
            isAuthenticated = true
        } catch let error as PortalAuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Sign in failed. Please check your connection and try again."
        }

        isLoading = false
    }

    // MARK: - Logout

    func logout() async {
        await authService.logout()
        isAuthenticated = false
        password = ""
    }
}
