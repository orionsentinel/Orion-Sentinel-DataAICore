import SwiftUI

struct ActiveWorkoutView: View {
    let workoutDay: WorkoutDay
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: WorkoutSessionViewModel
    @State private var repsInput = ""
    @State private var weightInput = ""
    @State private var showFinishConfirmation = false
    @State private var showExerciseDetail = false

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

    // MARK: - Main layout

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

            // Route to timed or rep-based bottom panel
            if viewModel.currentSetIsTimedSet {
                timedSetPanel
            } else {
                repSetPanel
            }
        }
    }

    // MARK: - Header

    private var workoutHeader: some View {
        HStack {
            Button { showFinishConfirmation = true } label: {
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
            Button { showExerciseDetail = true } label: {
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
            Text("Your progress so far will be saved.")
        }
        .sheet(isPresented: $showExerciseDetail) {
            if let exercise = viewModel.currentExercise {
                ExerciseDetailView(exercise: exercise.exercise)
            }
        }
    }

    // MARK: - Rest timer banner

    private var restTimerBanner: some View {
        HStack {
            Image(systemName: "timer").foregroundColor(Constants.Colors.athleanRed)
            Text("Rest  \(viewModel.restTimeRemaining)s")
                .font(.headline.bold())
                .foregroundColor(.white)
                .monospacedDigit()
            Spacer()
            Button("Skip Rest") { viewModel.stopRestTimer() }
                .font(.subheadline.bold())
                .foregroundColor(Constants.Colors.athleanRed)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Constants.Colors.athleanRed.opacity(0.1))
    }

    // MARK: - Exercise area (shared for both set types)

    private func exerciseContent(_ workoutExercise: WorkoutExercise) -> some View {
        VStack(spacing: 14) {
            AsyncImage(url: URL(string: workoutExercise.exercise.thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Constants.Colors.cardBackground.overlay(
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 48))
                        .foregroundColor(Constants.Colors.textSecondary)
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: viewModel.currentSetIsTimedSet ? 160 : 200)
            .clipped()

            VStack(spacing: 6) {
                Text(workoutExercise.exercise.name)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let set = viewModel.currentSet {
                    HStack(spacing: 12) {
                        Text("Set \(set.setNumber) of \(workoutExercise.sets.count)")
                            .font(.subheadline)
                            .foregroundColor(Constants.Colors.textSecondary)
                        Text("·")
                            .foregroundColor(Constants.Colors.textSecondary)
                        Text(setLabel(for: set))
                            .font(.subheadline.bold())
                            .foregroundColor(Constants.Colors.athleanRed)
                    }
                }

                setProgressDots(for: workoutExercise)
            }
            .padding(.horizontal)
        }
    }

    private func setLabel(for set: ExerciseSet) -> String {
        if let secs = viewModel.timedDuration(for: set) {
            return "\(secs)s hold"
        }
        return "\(set.targetReps) reps"
    }

    private func setProgressDots(for workoutExercise: WorkoutExercise) -> some View {
        HStack(spacing: 8) {
            ForEach(workoutExercise.sets.indices, id: \.self) { i in
                Circle()
                    .fill(
                        i < viewModel.currentSetIndex
                            ? Constants.Colors.success
                            : i == viewModel.currentSetIndex
                                ? Constants.Colors.athleanRed
                                : Constants.Colors.secondaryBackground
                    )
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut, value: viewModel.currentSetIndex)
            }
        }
    }

    // MARK: - Timed set panel

    private var timedSetPanel: some View {
        VStack(spacing: 0) {
            Divider().background(Constants.Colors.secondaryBackground)

            VStack(spacing: 20) {
                // Countdown ring
                ExerciseCountdownRing(viewModel: viewModel)
                    .frame(width: 180, height: 180)

                // Controls
                HStack(spacing: 16) {
                    // Skip
                    Button {
                        viewModel.skipSet()
                        viewModel.stopRestTimer()
                    } label: {
                        Text("Skip")
                            .font(.subheadline.bold())
                            .foregroundColor(Constants.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Constants.Colors.cardBackground)
                            .cornerRadius(Constants.UI.cornerRadius)
                    }

                    // Start / Pause / Reset (after completion)
                    if viewModel.exerciseTimerCompleted {
                        // Brief "done" button - auto-advances so this rarely shows
                        Label("Done!", systemImage: "checkmark.circle.fill")
                            .font(.headline.bold())
                            .foregroundColor(Constants.Colors.success)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else if !viewModel.isExerciseTimerRunning {
                        Button {
                            viewModel.startExerciseTimer()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text(viewModel.exerciseTimerTotal == 0 ? "Start Timer" : "Resume")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Constants.Colors.athleanRed)
                            .foregroundColor(.white)
                            .cornerRadius(Constants.UI.cornerRadius)
                        }
                    } else {
                        // Running: Pause + Reset
                        Button {
                            viewModel.pauseResumeExerciseTimer()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.isExerciseTimerPaused ? "play.fill" : "pause.fill")
                                Text(viewModel.isExerciseTimerPaused ? "Resume" : "Pause")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(viewModel.isExerciseTimerPaused
                                        ? Constants.Colors.athleanRed
                                        : Constants.Colors.cardBackground)
                            .foregroundColor(.white)
                            .cornerRadius(Constants.UI.cornerRadius)
                        }
                    }

                    // Reset (shown once timer has started)
                    if viewModel.exerciseTimerTotal > 0 && !viewModel.exerciseTimerCompleted {
                        Button {
                            viewModel.resetExerciseTimer()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.body.bold())
                                .foregroundColor(Constants.Colors.textSecondary)
                                .padding(14)
                                .background(Constants.Colors.cardBackground)
                                .cornerRadius(Constants.UI.cornerRadius)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 16)
            .background(Constants.Colors.athleanDark)
        }
    }

    // MARK: - Rep-based set panel

    private var repSetPanel: some View {
        VStack(spacing: 12) {
            Divider().background(Constants.Colors.secondaryBackground)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("REPS")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.textSecondary)
                        .tracking(1)
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
                    Text("WEIGHT (lbs)")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.textSecondary)
                        .tracking(1)
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
                    viewModel.logSet(reps: Int(repsInput) ?? 0, weight: Double(weightInput))
                    repsInput = ""
                    weightInput = ""
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Log Set").fontWeight(.bold)
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

    // MARK: - Workout complete

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
            HStack(spacing: 32) {
                summaryStatView(value: viewModel.elapsedTimeString, label: "Duration")
                summaryStatView(
                    value: "\(viewModel.exerciseLogs.flatMap { $0.setLogs }.count)",
                    label: "Sets Done"
                )
            }
            Spacer()
            Button {
                Task {
                    await viewModel.saveWorkout()
                    appState.isWorkoutActive = false
                }
            } label: {
                if viewModel.isSaving { ProgressView().tint(.white) }
                else { Text("Save & Finish") }
            }
            .athleanButtonStyle()
            .padding(.horizontal)
            .padding(.bottom, 48)
        }
    }

    private func summaryStatView(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title.bold().monospacedDigit()).foregroundColor(Constants.Colors.athleanRed)
            Text(label).font(.caption).foregroundColor(Constants.Colors.textSecondary)
        }
    }
}

// MARK: - Countdown ring component

struct ExerciseCountdownRing: View {
    @ObservedObject var viewModel: WorkoutSessionViewModel
    @State private var pulseScale: CGFloat = 1.0

    private var ringColor: Color {
        let p = viewModel.exerciseTimerProgress
        if viewModel.exerciseTimerCompleted { return Constants.Colors.success }
        if p > 0.5 { return Constants.Colors.athleanRed }
        if p > 0.2 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(Constants.Colors.secondaryBackground, lineWidth: 12)

            // Progress ring — shrinks as time runs out
            Circle()
                .trim(from: 0, to: viewModel.exerciseTimerProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: viewModel.exerciseTimerSeconds)

            // Center content
            VStack(spacing: 4) {
                if viewModel.exerciseTimerCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Constants.Colors.success)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                                pulseScale = 1.15
                            }
                        }
                } else {
                    Text(viewModel.exerciseTimerString)
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 1), value: viewModel.exerciseTimerSeconds)

                    if viewModel.isExerciseTimerPaused {
                        Text("PAUSED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                            .tracking(2)
                    } else if viewModel.isExerciseTimerRunning {
                        Text("GO")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(ringColor)
                            .tracking(3)
                    } else {
                        Text("READY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Constants.Colors.textSecondary)
                            .tracking(2)
                    }
                }
            }
        }
    }
}
