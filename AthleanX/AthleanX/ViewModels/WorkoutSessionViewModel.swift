import Foundation
import Combine

@MainActor
final class WorkoutSessionViewModel: ObservableObject {
    @Published var workoutDay: WorkoutDay
    @Published var currentExerciseIndex = 0
    @Published var currentSetIndex = 0
    @Published var isRestTimerActive = false
    @Published var restTimeRemaining = 0
    @Published var elapsedSeconds = 0
    @Published var isCompleted = false
    @Published var isSaving = false
    @Published var exerciseLogs: [ExerciseLog] = []

    private var restTimer: Timer?
    private var workoutTimer: Timer?
    private var startTime = Date()

    init(workoutDay: WorkoutDay) {
        self.workoutDay = workoutDay
        initializeLogs()
        startWorkoutTimer()
    }

    var currentExercise: WorkoutExercise? {
        guard currentExerciseIndex < workoutDay.exercises.count else { return nil }
        return workoutDay.exercises[currentExerciseIndex]
    }

    var currentSet: ExerciseSet? {
        guard let exercise = currentExercise,
              currentSetIndex < exercise.sets.count else { return nil }
        return exercise.sets[currentSetIndex]
    }

    var progressPercentage: Double {
        let total = workoutDay.exercises.flatMap { $0.sets }.count
        let completed = exerciseLogs.flatMap { $0.setLogs }.filter { $0.reps != nil }.count
        return total > 0 ? Double(completed) / Double(total) : 0
    }

    var elapsedTimeString: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

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

        if let logIndex = exerciseLogs.firstIndex(where: { $0.exerciseId == exercise.exercise.id }) {
            exerciseLogs[logIndex].setLogs.append(setLog)
        }

        startRestTimer(seconds: set.restSeconds)
        advanceToNextSet()
    }

    func skipSet() {
        advanceToNextSet()
    }

    private func advanceToNextSet() {
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

    func startRestTimer(seconds: Int) {
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

    private func startWorkoutTimer() {
        startTime = Date()
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds = Int(Date().timeIntervalSince(self.startTime))
            }
        }
    }

    private func finishWorkout() {
        workoutTimer?.invalidate()
        isCompleted = true
    }

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
        isSaving = false
    }

    private func initializeLogs() {
        exerciseLogs = workoutDay.exercises.map { workoutExercise in
            ExerciseLog(
                id: UUID(),
                exerciseId: workoutExercise.exercise.id,
                exerciseName: workoutExercise.exercise.name,
                setLogs: []
            )
        }
    }

    private func checkIfPR(exerciseId: Int, reps: Int?, weight: Double?) -> Bool {
        false // would compare against stored PRs
    }

    deinit {
        restTimer?.invalidate()
        workoutTimer?.invalidate()
    }
}
