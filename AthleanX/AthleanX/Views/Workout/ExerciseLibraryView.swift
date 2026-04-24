import SwiftUI

struct ExerciseLibraryView: View {
    @State private var exercises: [Exercise] = []
    @State private var filter = ExerciseFilter()
    @State private var isLoading = false
    @State private var selectedMuscle: Exercise.MuscleGroup?

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    muscleGroupPicker
                    exerciseList
                }
            }
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadExercises() }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Constants.Colors.textSecondary)
            TextField("Search exercises...", text: $filter.searchText)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .onChange(of: filter.searchText) {
                    Task { await loadExercises() }
                }
        }
        .padding(10)
        .background(Constants.Colors.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var muscleGroupPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                muscleChip(nil, label: "All")
                ForEach(Exercise.MuscleGroup.allCases, id: \.self) { muscle in
                    muscleChip(muscle, label: muscle.displayName)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func muscleChip(_ muscle: Exercise.MuscleGroup?, label: String) -> some View {
        Button {
            selectedMuscle = muscle
            filter.muscleGroups = muscle.map { [$0] } ?? []
            Task { await loadExercises() }
        } label: {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(selectedMuscle == muscle ? .white : Constants.Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedMuscle == muscle
                            ? Constants.Colors.athleanRed
                            : Constants.Colors.cardBackground)
                .cornerRadius(20)
        }
    }

    private var exerciseList: some View {
        Group {
            if isLoading {
                ProgressView().tint(Constants.Colors.athleanRed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(exercises) { exercise in
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                        ExerciseRowView(exercise: exercise)
                    }
                    .listRowBackground(Constants.Colors.cardBackground)
                    .listRowSeparatorTint(Constants.Colors.secondaryBackground)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func loadExercises() async {
        isLoading = true
        exercises = (try? await WorkoutService.shared.fetchExercises(filter: filter)) ?? []
        isLoading = false
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: exercise.thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Constants.Colors.secondaryBackground
                    .overlay(Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(Constants.Colors.textSecondary))
            }
            .frame(width: 52, height: 52)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(exercise.primaryMuscles.map { $0.displayName }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Constants.Colors.athleanDark.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VideoPlayerView(videoURL: exercise.videoURL, thumbnailURL: exercise.thumbnailURL)
                        .frame(height: 240)

                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exercise.name)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            muscleTagRow
                        }

                        Picker("", selection: $selectedTab) {
                            Text("Instructions").tag(0)
                            Text("Cues").tag(1)
                            Text("Mistakes").tag(2)
                        }
                        .pickerStyle(.segmented)

                        switch selectedTab {
                        case 0: instructionsList
                        case 1: cuesList
                        case 2: mistakesList
                        default: EmptyView()
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var muscleTagRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PRIMARY")
                .font(.caption2.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                            .font(.caption.bold())
                            .foregroundColor(Constants.Colors.athleanRed)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Constants.Colors.athleanRed.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    private var instructionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(exercise.instructions.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.athleanRed)
                        .frame(width: 20, height: 20)
                        .background(Constants.Colors.athleanRed.opacity(0.15))
                        .clipShape(Circle())
                    Text(exercise.instructions[i])
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineSpacing(4)
                }
            }
        }
    }

    private var cuesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(exercise.coachingCues, id: \.self) { cue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Constants.Colors.success)
                        .font(.caption)
                    Text(cue)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var mistakesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(exercise.commonMistakes, id: \.self) { mistake in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(mistake)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
    }
}
