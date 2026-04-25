import Foundation

struct ProgressEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    var weight: Double? // lbs or kg
    var bodyFatPercentage: Double?
    var measurements: Measurements?
    var photos: [ProgressPhoto]
    var notes: String?

    struct Measurements: Codable {
        var chest: Double?
        var waist: Double?
        var hips: Double?
        var leftArm: Double?
        var rightArm: Double?
        var leftThigh: Double?
        var rightThigh: Double?
        var neck: Double?
    }

    struct ProgressPhoto: Codable, Identifiable {
        let id: UUID
        let localPath: String
        let angle: PhotoAngle

        enum PhotoAngle: String, Codable {
            case front, side, back
            var displayName: String { rawValue.capitalized }
        }
    }
}

struct WorkoutHistory: Codable, Identifiable {
    let id: UUID
    let date: Date
    let programId: Int
    let programName: String
    let weekNumber: Int
    let dayNumber: Int
    let workoutTitle: String
    let duration: Int // minutes
    let exerciseLogs: [ExerciseLog]
    var totalVolume: Double { exerciseLogs.reduce(0) { $0 + $1.totalVolume } }
}

struct ExerciseLog: Codable, Identifiable {
    let id: UUID
    let exerciseId: Int
    let exerciseName: String
    var setLogs: [SetLog]

    var totalVolume: Double {
        setLogs.reduce(0) { $0 + (($1.weight ?? 0) * Double($1.reps ?? 0)) }
    }

    var bestSet: SetLog? {
        setLogs.max(by: { (($0.weight ?? 0) * Double($0.reps ?? 0)) < (($1.weight ?? 0) * Double($1.reps ?? 0)) })
    }
}

struct SetLog: Codable, Identifiable {
    let id: UUID
    let setNumber: Int
    var reps: Int?
    var weight: Double?
    var duration: Int? // seconds for timed sets
    var isPersonalRecord: Bool
}

struct PersonalRecord: Codable, Identifiable {
    let id: UUID
    let exerciseId: Int
    let exerciseName: String
    let weight: Double
    let reps: Int
    let achievedDate: Date
    let oneRepMax: Double // estimated
}
