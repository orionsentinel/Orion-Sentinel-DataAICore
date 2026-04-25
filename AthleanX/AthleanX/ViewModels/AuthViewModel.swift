import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var isCheckingSession = true
    @Published var errorMessage: String?
    @Published var showBiometricPrompt = false
    @Published var offerBiometricSave = false   // shown after first password login

    @Published var email = ""
    @Published var password = ""
    @Published var rememberMe = true

    private let authService = AuthService.shared
    private let biometric = BiometricAuthService.shared

    var biometryLabel: String { biometric.biometryLabel }
    var biometryIcon: String { biometric.biometryIcon }
    var canUseBiometrics: Bool { biometric.isAvailable && biometric.hasStoredCredentials() }

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Session restore

    private func restoreSession() async {
        isCheckingSession = true
        let remember = UserDefaults.standard.bool(forKey: "rememberMe")
        if remember {
            isAuthenticated = await authService.restoreSession()
        }
        if let saved = authService.savedEmail, !saved.isEmpty {
            email = saved
        }
        // Auto-trigger biometrics if session expired but credentials saved
        if !isAuthenticated && biometric.isAvailable && biometric.hasStoredCredentials() {
            showBiometricPrompt = true
        }
        isCheckingSession = false
    }

    // MARK: - Password login

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

            // Offer to save with biometrics if available and not already saved
            if biometric.isAvailable && !biometric.hasStoredCredentials() {
                offerBiometricSave = true
            }
            isAuthenticated = true
        } catch let error as PortalAuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Sign in failed. Please check your connection and try again."
        }

        isLoading = false
    }

    // MARK: - Biometric login

    func loginWithBiometrics() async {
        isLoading = true
        errorMessage = nil

        do {
            let (savedEmail, savedPassword) = try await biometric.authenticateAndRetrieve()
            email = savedEmail
            password = savedPassword
            try await authService.login(email: savedEmail, password: savedPassword)
            isAuthenticated = true
        } catch let error as BiometricAuthService.BiometricError {
            if case .userCancelled = error {
                // Do nothing — user deliberately dismissed
            } else {
                errorMessage = error.errorDescription
            }
            showBiometricPrompt = false
        } catch let error as PortalAuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Sign in failed. Please try again."
        }

        isLoading = false
    }

    // MARK: - Biometric credential save

    func enableBiometricSave() {
        try? biometric.saveCredentials(email: email, password: password)
        offerBiometricSave = false
    }

    func declineBiometricSave() {
        offerBiometricSave = false
    }

    // MARK: - Logout

    func logout() async {
        await authService.logout()
        isAuthenticated = false
        password = ""
        // Keep email for convenience; clear biometric prompt state
        showBiometricPrompt = false
    }
}
