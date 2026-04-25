import Foundation
import UIKit

@MainActor
final class WorkoutSessionViewModel: ObservableObject {
    @Published var workoutDay: WorkoutDay
    @Published var currentExerciseIndex = 0
    @Published var currentSetIndex = 0

    // Rest timer
    @Published var isRestTimerActive = false
    @Published var restTimeRemaining = 0

    // Exercise countdown timer (for timed sets)
    @Published var exerciseTimerSeconds = 0
    @Published var exerciseTimerTotal = 0
    @Published var isExerciseTimerRunning = false
    @Published var isExerciseTimerPaused = false
    @Published var exerciseTimerCompleted = false

    // Workout
    @Published var elapsedSeconds = 0
    @Published var isCompleted = false
    @Published var isSaving = false
    @Published var exerciseLogs: [ExerciseLog] = []

    private var restTimer: Timer?
    private var workoutTimer: Timer?
    private var exerciseTimer: Timer?
    private var startTime = Date()

    init(workoutDay: WorkoutDay) {
        self.workoutDay = workoutDay
        initializeLogs()
        startWorkoutTimer()
    }

    // MARK: - Current state

    var currentExercise: WorkoutExercise? {
        guard currentExerciseIndex < workoutDay.exercises.count else { return nil }
        return workoutDay.exercises[currentExerciseIndex]
    }

    var currentSet: ExerciseSet? {
        guard let exercise = currentExercise,
              currentSetIndex < exercise.sets.count else { return nil }
        return exercise.sets[currentSetIndex]
    }

    var currentSetIsTimedSet: Bool {
        guard let set = currentSet else { return false }
        return timedDuration(for: set) != nil
    }

    var progressPercentage: Double {
        let total = workoutDay.exercises.flatMap { $0.sets }.count
        let completed = exerciseLogs.flatMap { $0.setLogs }.count
        return total > 0 ? Double(completed) / Double(total) : 0
    }

    var elapsedTimeString: String {
        formatTime(elapsedSeconds)
    }

    var exerciseTimerString: String {
        formatTime(exerciseTimerSeconds)
    }

    var exerciseTimerProgress: Double {
        guard exerciseTimerTotal > 0 else { return 1 }
        return Double(exerciseTimerSeconds) / Double(exerciseTimerTotal)
    }

    // MARK: - Rep-based set logging

    func logSet(reps: Int, weight: Double?) {
        guard let exercise = currentExercise, let set = currentSet else { return }
        let setLog = SetLog(
            id: UUID(),
            setNumber: set.setNumber,
            reps: reps,
            weight: weight,
            duration: nil,
            isPersonalRecord: checkIfPR(exerciseId: exercise.exercise.id, reps: reps, weight: weight)
        )
        appendLog(setLog, for: exercise)
        haptic(.medium)
        startRestTimer(seconds: set.restSeconds)
        advanceToNextSet()
    }

    func skipSet() {
        resetExerciseTimerState()
        advanceToNextSet()
    }

    // MARK: - Exercise countdown timer

    func startExerciseTimer() {
        guard let set = currentSet,
              let duration = timedDuration(for: set) else { return }

        if exerciseTimerTotal == 0 {
            exerciseTimerTotal = duration
            exerciseTimerSeconds = duration
        }
        isExerciseTimerRunning = true
        isExerciseTimerPaused = false
        exerciseTimerCompleted = false

        exerciseTimer?.invalidate()
        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isExerciseTimerRunning, !self.isExerciseTimerPaused else { return }
                if self.exerciseTimerSeconds > 0 {
                    self.exerciseTimerSeconds -= 1
                    // Countdown haptics at 10, 5, 3, 2, 1 seconds
                    if [10, 5, 3, 2, 1].contains(self.exerciseTimerSeconds) {
                        self.haptic(.light)
                    }
                } else {
                    self.completeExerciseTimer()
                }
            }
        }
    }

    func pauseResumeExerciseTimer() {
        isExerciseTimerPaused.toggle()
    }

    func resetExerciseTimer() {
        exerciseTimer?.invalidate()
        isExerciseTimerRunning = false
        isExerciseTimerPaused = false
        exerciseTimerCompleted = false
        exerciseTimerSeconds = exerciseTimerTotal
    }

    private func completeExerciseTimer() {
        exerciseTimer?.invalidate()
        isExerciseTimerRunning = false
        exerciseTimerCompleted = true
        haptic(.heavy)

        guard let exercise = currentExercise, let set = currentSet else { return }
        let setLog = SetLog(
            id: UUID(),
            setNumber: set.setNumber,
            reps: nil,
            weight: nil,
            duration: exerciseTimerTotal,
            isPersonalRecord: false
        )
        appendLog(setLog, for: exercise)
        startRestTimer(seconds: set.restSeconds)

        // Brief delay so user sees the "Complete!" state before advancing
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            advanceToNextSet()
        }
    }

    private func resetExerciseTimerState() {
        exerciseTimer?.invalidate()
        isExerciseTimerRunning = false
        isExerciseTimerPaused = false
        exerciseTimerCompleted = false
        exerciseTimerTotal = 0
        exerciseTimerSeconds = 0
    }

    // MARK: - Rest timer

    func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }
        restTimeRemaining = seconds
        isRestTimerActive = true
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.restTimeRemaining > 0 {
                    self.restTimeRemaining -= 1
                } else {
                    self.stopRestTimer()
                }
            }
        }
    }

    func stopRestTimer() {
        restTimer?.invalidate()
        isRestTimerActive = false
        restTimeRemaining = 0
    }

    // MARK: - Navigation

    private func advanceToNextSet() {
        resetExerciseTimerState()
        guard let exercise = currentExercise else { return }
        if currentSetIndex + 1 < exercise.sets.count {
            currentSetIndex += 1
        } else if currentExerciseIndex + 1 < workoutDay.exercises.count {
            currentExerciseIndex += 1
            currentSetIndex = 0
        } else {
            finishWorkout()
        }
    }

    private func finishWorkout() {
        workoutTimer?.invalidate()
        isCompleted = true
        haptic(.heavy)
    }

    // MARK: - Workout timer

    private func startWorkoutTimer() {
        startTime = Date()
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds = Int(Date().timeIntervalSince(self.startTime))
            }
        }
    }

    // MARK: - Save

    func saveWorkout() async {
        isSaving = true
        let history = WorkoutHistory(
            id: UUID(),
            date: startTime,
            programId: 0,
            programName: "",
            weekNumber: 0,
            dayNumber: workoutDay.dayNumber,
            workoutTitle: workoutDay.title,
            duration: elapsedSeconds / 60,
            exerciseLogs: exerciseLogs
        )
        try? await WorkoutService.shared.completeWorkout(workoutDayId: workoutDay.id, history: history)
        await saveToHealthKit()
        isSaving = false
    }

    private func saveToHealthKit() async {
        guard elapsedSeconds > 0 else { return }
        // ~6.5 kcal/min is a reasonable estimate for moderate-intensity strength training
        let estimatedKcal = max(1, Double(elapsedSeconds) / 60.0 * 6.5)
        try? await HealthKitService.shared.saveWorkout(
            start: startTime,
            duration: elapsedSeconds,
            estimatedCalories: estimatedKcal
        )
    }

    // MARK: - Helpers

    /// Parse seconds from strings like "60 sec", "30s", "1 min", "2 min 30 sec"
    func timedDuration(for set: ExerciseSet) -> Int? {
        let s = set.targetReps.lowercased().trimmingCharacters(in: .whitespaces)
        guard s.contains("sec") || s.contains(" s") || s.hasSuffix("s") || s.contains("min") else {
            return nil
        }
        var total = 0
        // Extract minutes
        if s.contains("min") {
            let parts = s.components(separatedBy: "min")
            if let minStr = parts.first,
               let mins = Int(minStr.trimmingCharacters(in: .init(charactersIn: " \t"))) {
                total += mins * 60
            }
        }
        // Extract seconds
        if s.contains("sec") || (s.contains("s") && !s.contains("min")) {
            let digits = s.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            if let secs = digits.last {
                total += secs
            }
        } else if !s.contains("min") {
            // Pure number with trailing "s"
            let digits = s.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            if let secs = digits.first { total += secs }
        }
        return total > 0 ? total : nil
    }

    private func appendLog(_ log: SetLog, for exercise: WorkoutExercise) {
        if let idx = exerciseLogs.firstIndex(where: { $0.exerciseId == exercise.exercise.id }) {
            exerciseLogs[idx].setLogs.append(log)
        }
    }

    private func initializeLogs() {
        exerciseLogs = workoutDay.exercises.map { we in
            ExerciseLog(id: UUID(), exerciseId: we.exercise.id, exerciseName: we.exercise.name, setLogs: [])
        }
    }

    private func checkIfPR(exerciseId: Int, reps: Int?, weight: Double?) -> Bool { false }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    deinit {
        restTimer?.invalidate()
        workoutTimer?.invalidate()
        exerciseTimer?.invalidate()
    }
}
