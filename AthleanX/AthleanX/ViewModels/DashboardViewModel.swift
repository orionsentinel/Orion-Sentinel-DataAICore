import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var activeProgram: Program?
    @Published var todayWorkout: WorkoutDay?
    @Published var recentHistory: [WorkoutHistory] = []
    @Published var weeklyStats: WeeklyStats?
    @Published var isLoading = false
    @Published var errorMessage: String?

    struct WeeklyStats {
        let workoutsCompleted: Int
        let workoutsPlanned: Int
        let totalVolume: Double
        let totalMinutes: Int

        var completionPercentage: Double {
            guard workoutsPlanned > 0 else { return 0 }
            return Double(workoutsCompleted) / Double(workoutsPlanned)
        }
    }

    func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        async let programTask = WorkoutService.shared.fetchActiveProgram()
        async let todayTask = WorkoutService.shared.fetchTodayWorkout()
        async let historyTask = WorkoutService.shared.fetchWorkoutHistory(page: 1, limit: 5)

        do {
            let (program, today, history) = try await (programTask, todayTask, historyTask)
            activeProgram = program
            todayWorkout = today
            recentHistory = history
            computeWeeklyStats(from: history)
        } catch {
            errorMessage = "Failed to load dashboard. Pull to refresh."
        }
        isLoading = false
    }

    private func computeWeeklyStats(from history: [WorkoutHistory]) {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let thisWeek = history.filter { $0.date >= weekStart }

        weeklyStats = WeeklyStats(
            workoutsCompleted: thisWeek.count,
            workoutsPlanned: activeProgram?.daysPerWeek ?? 0,
            totalVolume: thisWeek.reduce(0) { $0 + $1.totalVolume },
            totalMinutes: thisWeek.reduce(0) { $0 + $1.duration }
        )
    }
}
