import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let firstName: String
    let lastName: String
    let avatarURL: String?
    let membershipType: MembershipType
    let membershipExpiry: Date?
    var goals: [FitnessGoal]
    var currentProgramId: Int?
    var currentWeek: Int
    var currentDay: Int

    var fullName: String { "\(firstName) \(lastName)" }

    enum MembershipType: String, Codable {
        case allAxcess = "all_axcess"
        case standard = "standard"
        case trial = "trial"
    }
}

enum FitnessGoal: String, Codable, CaseIterable {
    case buildMuscle = "build_muscle"
    case loseFat = "lose_fat"
    case improveAthleticism = "improve_athleticism"
    case increaseStrength = "increase_strength"
    case generalFitness = "general_fitness"

    var displayName: String {
        switch self {
        case .buildMuscle: return "Build Muscle"
        case .loseFat: return "Lose Fat"
        case .improveAthleticism: return "Improve Athleticism"
        case .increaseStrength: return "Increase Strength"
        case .generalFitness: return "General Fitness"
        }
    }

    var iconName: String {
        switch self {
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .loseFat: return "flame.fill"
        case .improveAthleticism: return "figure.run"
        case .increaseStrength: return "dumbbell.fill"
        case .generalFitness: return "heart.fill"
        }
    }
}

struct AuthToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}
