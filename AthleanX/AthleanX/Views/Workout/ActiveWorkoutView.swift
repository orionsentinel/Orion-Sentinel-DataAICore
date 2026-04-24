import SwiftUI

struct ActiveWorkoutView: View {
    let workoutDay: WorkoutDay
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: WorkoutSessionViewModel
    @State private var showExerciseDetail = false
    @State private var repsInput = ""
    @State private var weightInput = ""
    @State private var showFinishConfirmation = false

    init(workoutDay: WorkoutDay) {
        self.workoutDay = workoutDay
        _viewModel = StateObject(wrappedValue: WorkoutSessionViewModel(workoutDay: workoutDay))
    }

    var body: some View {
        ZStack {
            Constants.Colors.athleanDark.ignoresSafeArea()
            if viewModel.isCompleted {
                workoutCompleteView
            } else {
                mainWorkoutView
            }
        }
    }

    private var mainWorkoutView: some View {
        VStack(spacing: 0) {
            workoutHeader
            if viewModel.isRestTimerActive {
                restTimerBanner
            }
            if let exercise = viewModel.currentExercise {
                exerciseContent(exercise)
            }
            Spacer()
            setInputArea
        }
    }

    private var workoutHeader: some View {
        HStack {
            Button {
                showFinishConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.body.bold())
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Constants.Colors.cardBackground)
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(viewModel.elapsedTimeString)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(.white)
                ProgressView(value: viewModel.progressPercentage)
                    .tint(Constants.Colors.athleanRed)
                    .frame(width: 80)
            }
            Spacer()
            Button {
                showExerciseDetail = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.body.bold())
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Constants.Colors.cardBackground)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Constants.Colors.athleanDark)
        .alert("End Workout?", isPresented: $showFinishConfirmation) {
            Button("Save & Exit", role: .destructive) {
                Task {
                    await viewModel.saveWorkout()
                    appState.isWorkoutActive = false
                }
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("You can save your progress before leaving.")
        }
    }

    private var restTimerBanner: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundColor(Constants.Colors.athleanRed)
            Text("Rest: \(viewModel.restTimeRemaining)s")
                .font(.headline.bold())
                .foregroundColor(.white)
                .monospacedDigit()
            Spacer()
            Button("Skip Rest") {
                viewModel.stopRestTimer()
            }
            .font(.subheadline.bold())
            .foregroundColor(Constants.Colors.athleanRed)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Constants.Colors.athleanRed.opacity(0.1))
    }

    private func exerciseContent(_ workoutExercise: WorkoutExercise) -> some View {
        VStack(spacing: 16) {
            AsyncImage(url: URL(string: workoutExercise.exercise.thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Constants.Colors.cardBackground
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 48))
                            .foregroundColor(Constants.Colors.textSecondary)
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()

            VStack(spacing: 8) {
                Text(workoutExercise.exercise.name)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let currentSet = viewModel.currentSet {
                    Text("Set \(currentSet.setNumber) of \(workoutExercise.sets.count)")
                        .font(.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                    Text("Target: \(currentSet.targetReps) reps")
                        .font(.headline)
                        .foregroundColor(Constants.Colors.athleanRed)
                }

                setProgressDots(for: workoutExercise)
            }
            .padding(.horizontal)
        }
    }

    private func setProgressDots(for workoutExercise: WorkoutExercise) -> some View {
        HStack(spacing: 8) {
            ForEach(workoutExercise.sets.indices, id: \.self) { i in
                Circle()
                    .fill(i < viewModel.currentSetIndex
                          ? Constants.Colors.success
                          : i == viewModel.currentSetIndex
                          ? Constants.Colors.athleanRed
                          : Constants.Colors.secondaryBackground)
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var setInputArea: some View {
        VStack(spacing: 12) {
            Divider().background(Constants.Colors.secondaryBackground)
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("REPS").font(.caption.bold()).foregroundColor(Constants.Colors.textSecondary).tracking(1)
                    TextField("0", text: $repsInput)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .background(Constants.Colors.cardBackground)
                        .cornerRadius(8)
                }
                VStack(spacing: 4) {
                    Text("WEIGHT (lbs)").font(.caption.bold()).foregroundColor(Constants.Colors.textSecondary).tracking(1)
                    TextField("BW", text: $weightInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .background(Constants.Colors.cardBackground)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Skip") {
                    viewModel.skipSet()
                    repsInput = ""
                    weightInput = ""
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Constants.Colors.cardBackground)
                .foregroundColor(Constants.Colors.textSecondary)
                .cornerRadius(Constants.UI.cornerRadius)

                Button {
                    let reps = Int(repsInput) ?? 0
                    let weight = Double(weightInput)
                    viewModel.logSet(reps: reps, weight: weight)
                    repsInput = ""
                    weightInput = ""
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Log Set")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Constants.Colors.athleanRed)
                .foregroundColor(.white)
                .cornerRadius(Constants.UI.cornerRadius)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Constants.Colors.athleanDark)
    }

    private var workoutCompleteView: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundColor(.yellow)

            VStack(spacing: 8) {
                Text("Workout Complete!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                Text("Great work. That's what separates you from the rest.")
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            workoutSummaryStats

            Spacer()

            Button {
                Task {
                    await viewModel.saveWorkout()
                    appState.isWorkoutActive = false
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Save & Finish")
                }
            }
            .athleanButtonStyle()
            .padding(.horizontal)
            .padding(.bottom, 48)
        }
    }

    private var workoutSummaryStats: some View {
        HStack(spacing: 24) {
            summaryStatView(value: viewModel.elapsedTimeString, label: "Duration")
            summaryStatView(
                value: "\(viewModel.exerciseLogs.flatMap { $0.setLogs }.filter { $0.reps != nil }.count)",
                label: "Sets Done"
            )
        }
    }

    private func summaryStatView(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold().monospacedDigit())
                .foregroundColor(Constants.Colors.athleanRed)
            Text(label)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
        }
    }
}
