import Foundation

struct Exercise: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let description: String
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let equipment: [Equipment]
    let difficulty: Program.Difficulty
    let thumbnailURL: String
    let videoURL: String?
    let instructions: [String]
    let coachingCues: [String]
    let commonMistakes: [String]
    var isFavorited: Bool

    enum MuscleGroup: String, Codable, CaseIterable {
        case chest, back, shoulders, biceps, triceps
        case forearms, core, quads, hamstrings, glutes
        case calves, traps, lats

        var displayName: String { rawValue.capitalized }

        var bodyRegion: BodyRegion {
            switch self {
            case .chest, .back, .shoulders, .traps, .lats: return .upper
            case .biceps, .triceps, .forearms: return .arms
            case .core: return .core
            case .quads, .hamstrings, .glutes, .calves: return .lower
            }
        }
    }

    enum BodyRegion: String, CaseIterable {
        case upper = "Upper Body"
        case arms = "Arms"
        case core = "Core"
        case lower = "Lower Body"
    }
}

struct ExerciseFilter {
    var muscleGroups: [Exercise.MuscleGroup] = []
    var equipment: [Equipment] = []
    var difficulty: [Program.Difficulty] = []
    var searchText: String = ""

    var isActive: Bool {
        !muscleGroups.isEmpty || !equipment.isEmpty || !difficulty.isEmpty || !searchText.isEmpty
    }
}
