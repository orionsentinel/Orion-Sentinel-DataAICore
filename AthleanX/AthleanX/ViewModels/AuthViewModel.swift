import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var email = ""
    @Published var password = ""
    @Published var rememberMe = true

    private let authService = AuthService.shared

    init() {
        checkExistingSession()
    }

    private func checkExistingSession() {
        guard authService.isLoggedIn else { return }
        Task {
            do {
                isLoading = true
                currentUser = try await authService.fetchCurrentUser()
                isAuthenticated = true
            } catch {
                KeychainManager.shared.clearAll()
            }
            isLoading = false
        }
    }

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        guard email.isValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            currentUser = try await authService.login(email: email, password: password, rememberMe: rememberMe)
            isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Login failed. Please try again."
        }
        isLoading = false
    }

    func logout() async {
        isLoading = true
        try? await authService.logout()
        currentUser = nil
        isAuthenticated = false
        email = ""
        password = ""
        isLoading = false
    }
}
