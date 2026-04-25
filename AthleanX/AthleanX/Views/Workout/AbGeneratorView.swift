import SwiftUI

struct AbGeneratorView: View {
    @State private var selectedLevel: AbLevel = .intermediate
    @State private var generatedWorkout: WorkoutDay?
    @State private var isGenerating = false
    @State private var isWorkoutStarted = false
    @EnvironmentObject var appState: AppState

    enum AbLevel: String, CaseIterable {
        case beginner, intermediate, advanced

        var displayName: String { rawValue.capitalized }
        var description: String {
            switch self {
            case .beginner: return "Foundational core movements, bodyweight only"
            case .intermediate: return "Progressive overload, mix of weighted & bodyweight"
            case .advanced: return "High-intensity, weighted, maximum activation"
            }
        }
        var exerciseCount: Int {
            switch self { case .beginner: return 4; case .intermediate: return 6; case .advanced: return 8 }
        }
        var estimatedMinutes: Int {
            switch self { case .beginner: return 10; case .intermediate: return 15; case .advanced: return 20 }
        }
    }

    var body: some View {
        ZStack {
            Constants.Colors.athleanDark.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    header
                    levelPicker
                    levelDetail
                    if let workout = generatedWorkout {
                        workoutPreview(workout)
                    }
                    generateButton
                }
                .padding()
            }
        }
        .navigationTitle("Ab Generator")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isWorkoutStarted) {
            if let workout = generatedWorkout {
                ActiveWorkoutView(workoutDay: workout)
                    .environmentObject(appState)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Constants.Colors.athleanRed)
            Text("Unlimited Ab Workouts")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Science-based core training generated for your level")
                .font(.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var levelPicker: some View {
        HStack(spacing: 0) {
            ForEach(AbLevel.allCases, id: \.self) { level in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedLevel = level
                        generatedWorkout = nil
                    }
                } label: {
                    Text(level.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(selectedLevel == level ? .white : Constants.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedLevel == level ? Constants.Colors.athleanRed : Color.clear)
                }
            }
        }
        .background(Constants.Colors.cardBackground)
        .cornerRadius(10)
    }

    private var levelDetail: some View {
        HStack(spacing: 20) {
            metaPill("\(selectedLevel.exerciseCount) exercises", icon: "list.number")
            metaPill("~\(selectedLevel.estimatedMinutes) min", icon: "clock")
            metaPill(selectedLevel.displayName, icon: "speedometer")
        }
        .frame(maxWidth: .infinity)
    }

    private func metaPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption)
            Text(text).font(.caption.bold())
        }
        .foregroundColor(Constants.Colors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Constants.Colors.cardBackground)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func workoutPreview(_ workout: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GENERATED WORKOUT")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            ForEach(workout.exercises.indices, id: \.self) { i in
                let we = workout.exercises[i]
                HStack {
                    Text("\(i + 1).")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.athleanRed)
                        .frame(width: 20)
                    Text(we.exercise.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text(we.sets.first?.targetReps ?? "")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(.vertical, 4)
                if i < workout.exercises.count - 1 {
                    Divider().background(Constants.Colors.secondaryBackground)
                }
            }
        }
        .cardStyle()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var generateButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await generate() }
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(generatedWorkout == nil ? "Generate Workout" : "Regenerate")
                            .fontWeight(.bold)
                    }
                }
            }
            .disabled(isGenerating)
            .athleanButtonStyle()

            if generatedWorkout != nil {
                Button {
                    isWorkoutStarted = true
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start This Workout")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Constants.Colors.success)
                .foregroundColor(.white)
                .cornerRadius(Constants.UI.cornerRadius)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func generate() async {
        isGenerating = true
        withAnimation { generatedWorkout = nil }
        generatedWorkout = try? await WorkoutService.shared.generateAbWorkout(level: selectedLevel.rawValue)
        withAnimation { isGenerating = false }
    }
}
