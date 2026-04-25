import LocalAuthentication
import Security
import Foundation

final class BiometricAuthService {
    static let shared = BiometricAuthService()
    private init() {}

    private let credentialKey = "com.athleanx.app.biometric.credentials"

    // MARK: - Capability

    var biometryType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometryLabel: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometrics"
        }
    }

    var biometryIcon: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    // MARK: - Save credentials (called after a successful password login)

    func saveCredentials(email: String, password: String) throws {
        let payload = "\(email):\(password)"
        guard let data = payload.data(using: .utf8) else { return }

        // Biometric-protected Keychain item — invalidated if face/fingerprints change
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet],
            &error
        ) else {
            throw BiometricError.keychainSetupFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credentialKey,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access,
            kSecUseAuthenticationUISkip as String: true as AnyObject
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricError.saveFailed(status)
        }
    }

    func hasStoredCredentials() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credentialKey,
            kSecUseAuthenticationUISkip as String: true as AnyObject,
            kSecReturnAttributes as String: true
        ]
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
    }

    func clearStoredCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credentialKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Authenticate + retrieve credentials

    /// Presents biometric prompt, then returns (email, password) on success.
    func authenticateAndRetrieve() async throws -> (email: String, password: String) {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Use Password"

        let reason = "Sign in to ATHLEAN-X with \(biometryLabel)"

        let success: Bool
        do {
            success = try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let laError as LAError {
            throw BiometricError.from(laError)
        }

        guard success else { throw BiometricError.authFailed }

        // Fetch credentials (biometric already proven, so no UI prompt fires)
        let fetchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credentialKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: ctx
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(fetchQuery as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let payload = String(data: data, encoding: .utf8) else {
            throw BiometricError.credentialsMissing
        }

        let parts = payload.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { throw BiometricError.credentialsMissing }
        return (email: parts[0], password: parts[1])
    }

    // MARK: - Errors

    enum BiometricError: LocalizedError {
        case notAvailable
        case authFailed
        case userCancelled
        case credentialsMissing
        case keychainSetupFailed
        case saveFailed(OSStatus)
        case lockout

        static func from(_ error: LAError) -> BiometricError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel: return .userCancelled
            case .biometryLockout, .authenticationFailed: return .lockout
            case .biometryNotAvailable, .biometryNotEnrolled: return .notAvailable
            default: return .authFailed
            }
        }

        var errorDescription: String? {
            switch self {
            case .notAvailable: return "Biometric authentication is not available on this device."
            case .authFailed: return "Biometric authentication failed."
            case .userCancelled: return nil  // user deliberately cancelled, show nothing
            case .credentialsMissing: return "Saved credentials not found. Please sign in with your password."
            case .keychainSetupFailed: return "Could not set up secure storage."
            case .saveFailed: return "Could not save credentials securely."
            case .lockout: return "Too many failed attempts. Please sign in with your password."
            }
        }
    }
}
