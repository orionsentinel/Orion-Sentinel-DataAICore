import Foundation
import SwiftUI

enum Constants {
    enum API {
        static let baseURL = "https://portal.athleanx.com/api"
        static let portalBaseURL = "https://portal.athleanx.com"
        static let timeoutInterval: TimeInterval = 30
    }

    enum Keychain {
        static let accessTokenKey = "com.athleanx.app.accessToken"
        static let refreshTokenKey = "com.athleanx.app.refreshToken"
        static let userIdKey = "com.athleanx.app.userId"
    }

    enum UserDefaults {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let preferredWeightUnit = "preferredWeightUnit"
        static let preferredMeasurementUnit = "preferredMeasurementUnit"
        static let notificationsEnabled = "notificationsEnabled"
        static let workoutReminderTime = "workoutReminderTime"
    }

    enum Cache {
        static let programsCacheKey = "programsCache"
        static let exercisesCacheKey = "exercisesCache"
        static let cacheExpiryHours: Double = 24
    }

    enum UI {
        static let cornerRadius: CGFloat = 12
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let animationDuration: Double = 0.3
    }

    enum Colors {
        static let athleanRed = Color(hex: "#E53935")
        static let athleanDark = Color(hex: "#121212")
        static let cardBackground = Color(hex: "#1E1E1E")
        static let secondaryBackground = Color(hex: "#2A2A2A")
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#B0B0B0")
        static let accent = Color(hex: "#E53935")
        static let success = Color(hex: "#4CAF50")
        static let warning = Color(hex: "#FF9800")
    }
}
