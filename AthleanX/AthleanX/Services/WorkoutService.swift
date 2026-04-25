import Foundation

final class WorkoutService {
    static let shared = WorkoutService()
    private init() {}

    func fetchPrograms(filter: ProgramFilter? = nil) async throws -> [Program] {
        var queryItems: [URLQueryItem] = []
        if let filter = filter {
            if let goal = filter.goal { queryItems.append(.init(name: "goal", value: goal.rawValue)) }
            if let difficulty = filter.difficulty { queryItems.append(.init(name: "difficulty", value: difficulty.rawValue)) }
        }
        return try await APIClient.shared.request(.get("/programs", queryItems: queryItems))
    }

    func fetchProgram(id: Int) async throws -> Program {
        try await APIClient.shared.request(.get("/programs/\(id)"))
    }

    func fetchActiveProgram() async throws -> Program? {
        try? await APIClient.shared.request(.get("/programs/active"))
    }

    func enrollInProgram(id: Int) async throws -> Program {
        try await APIClient.shared.request(.post("/programs/\(id)/enroll", body: EmptyBody()))
    }

    func fetchTodayWorkout() async throws -> WorkoutDay? {
        try? await APIClient.shared.request(.get("/workouts/today"))
    }

    func fetchWorkoutDay(programId: Int, week: Int, day: Int) async throws -> WorkoutDay {
        try await APIClient.shared.request(.get("/programs/\(programId)/weeks/\(week)/days/\(day)"))
    }

    func completeWorkout(workoutDayId: Int, history: WorkoutHistory) async throws {
        struct CompleteRequest: Encodable {
            let workoutDayId: Int
            let duration: Int
            let exerciseLogs: [ExerciseLog]
        }
        let body = CompleteRequest(
            workoutDayId: workoutDayId,
            duration: history.duration,
            exerciseLogs: history.exerciseLogs
        )
        try await APIClient.shared.requestVoid(.post("/workouts/complete", body: body))
    }

    func fetchExercises(filter: ExerciseFilter? = nil) async throws -> [Exercise] {
        var queryItems: [URLQueryItem] = []
        if let filter = filter {
            if !filter.searchText.isEmpty {
                queryItems.append(.init(name: "q", value: filter.searchText))
            }
            filter.muscleGroups.forEach {
                queryItems.append(.init(name: "muscle", value: $0.rawValue))
            }
        }
        return try await APIClient.shared.request(.get("/exercises", queryItems: queryItems))
    }

    func fetchExercise(id: Int) async throws -> Exercise {
        try await APIClient.shared.request(.get("/exercises/\(id)"))
    }

    func fetchWorkoutHistory(page: Int = 1, limit: Int = 20) async throws -> [WorkoutHistory] {
        let queryItems = [URLQueryItem(name: "page", value: "\(page)"),
                          URLQueryItem(name: "limit", value: "\(limit)")]
        return try await APIClient.shared.request(.get("/workouts/history", queryItems: queryItems))
    }

    func fetchPersonalRecords() async throws -> [PersonalRecord] {
        try await APIClient.shared.request(.get("/workouts/personal-records"))
    }

    func generateAbWorkout(level: String = "intermediate") async throws -> WorkoutDay {
        let queryItems = [URLQueryItem(name: "level", value: level)]
        return try await APIClient.shared.request(.get("/workouts/ab-generator", queryItems: queryItems))
    }
}

struct ProgramFilter {
    var goal: FitnessGoal?
    var difficulty: Program.Difficulty?
    var equipment: Equipment?
}
