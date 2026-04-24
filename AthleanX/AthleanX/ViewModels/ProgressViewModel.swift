import Foundation

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published var workoutHistory: [WorkoutHistory] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var progressEntries: [ProgressEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddEntry = false

    var weightHistory: [(Date, Double)] {
        progressEntries.compactMap { entry in
            guard let weight = entry.weight else { return nil }
            return (entry.date, weight)
        }.sorted { $0.0 < $1.0 }
    }

    var totalWorkoutsThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return workoutHistory.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    var totalVolumeThisWeek: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return workoutHistory
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.totalVolume }
    }

    var streakDays: Int {
        var streak = 0
        var checkDate = Date()
        let calendar = Calendar.current

        for _ in 0..<365 {
            let dayWorkouts = workoutHistory.filter {
                calendar.isDate($0.date, equalTo: checkDate, toGranularity: .day)
            }
            if dayWorkouts.isEmpty { break }
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    func loadProgress() async {
        isLoading = true
        async let historyTask = WorkoutService.shared.fetchWorkoutHistory(page: 1, limit: 50)
        async let prTask = WorkoutService.shared.fetchPersonalRecords()

        do {
            let (history, prs) = try await (historyTask, prTask)
            workoutHistory = history
            personalRecords = prs
        } catch {
            errorMessage = "Failed to load progress data."
        }
        isLoading = false
    }

    func addProgressEntry(_ entry: ProgressEntry) {
        progressEntries.append(entry)
        progressEntries.sort { $0.date > $1.date }
    }
}
