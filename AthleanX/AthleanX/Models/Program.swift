import Foundation

struct Program: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let description: String
    let shortDescription: String
    let thumbnailURL: String
    let duration: Int // weeks
    let daysPerWeek: Int
    let difficulty: Difficulty
    let goals: [FitnessGoal]
    let equipment: [Equipment]
    let tags: [String]
    let weeks: [ProgramWeek]
    var isFavorited: Bool

    enum Difficulty: String, Codable, CaseIterable {
        case beginner, intermediate, advanced, elite

        var displayName: String { rawValue.capitalized }

        var color: String {
            switch self {
            case .beginner: return "green"
            case .intermediate: return "blue"
            case .advanced: return "orange"
            case .elite: return "red"
            }
        }
    }
}

enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, kettlebell, cableMachine, resistanceBand
    case pullupBar, bench, trx, bodyweightOnly, fullGym

    var displayName: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbells"
        case .kettlebell: return "Kettlebell"
        case .cableMachine: return "Cable Machine"
        case .resistanceBand: return "Resistance Bands"
        case .pullupBar: return "Pull-up Bar"
        case .bench: return "Bench"
        case .trx: return "TRX"
        case .bodyweightOnly: return "Bodyweight Only"
        case .fullGym: return "Full Gym"
        }
    }
}

struct ProgramWeek: Codable, Identifiable {
    let id: Int
    let weekNumber: Int
    let title: String
    let days: [WorkoutDay]
}

struct WorkoutDay: Codable, Identifiable {
    let id: Int
    let dayNumber: Int
    let title: String
    let type: DayType
    let exercises: [WorkoutExercise]
    let estimatedDuration: Int // minutes
    let notes: String?
    var isCompleted: Bool

    enum DayType: String, Codable {
        case workout, rest, active_recovery

        var displayName: String {
            switch self {
            case .workout: return "Workout"
            case .rest: return "Rest Day"
            case .active_recovery: return "Active Recovery"
            }
        }
    }
}

struct WorkoutExercise: Codable, Identifiable {
    let id: Int
    let exercise: Exercise
    let sets: [ExerciseSet]
    let notes: String?
    let supersetGroupId: Int?
    var order: Int
}

struct ExerciseSet: Codable, Identifiable {
    let id: Int
    let setNumber: Int
    let targetReps: String // "8-12" or "AMRAP" or "60 sec"
    let targetWeight: String? // "Bodyweight" or specific weight
    let restSeconds: Int
    var completedReps: Int?
    var completedWeight: Double?
    var isCompleted: Bool
}
