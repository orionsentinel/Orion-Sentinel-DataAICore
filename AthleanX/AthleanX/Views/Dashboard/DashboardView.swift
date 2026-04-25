import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showProgramSelector = false

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                if viewModel.isLoading && viewModel.activeProgram == nil {
                    LoadingView(message: "Loading your workout…")
                } else if viewModel.activeProgram == nil {
                    noProgramState
                } else {
                    todayContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .refreshable { await viewModel.loadDashboard() }
            .task { await viewModel.loadDashboard() }
            .sheet(isPresented: $showProgramSelector) {
                ProgramSelectorView()
            }
            .fullScreenCover(isPresented: $appState.isWorkoutActive) {
                if let workout = appState.todayWorkout {
                    ActiveWorkoutView(workoutDay: workout)
                        .environmentObject(appState)
                }
            }
        }
    }

    // MARK: - No program selected state

    private var noProgramState: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 16) {
                AthleanLogoMark(size: 72)
                VStack(spacing: 6) {
                    Text("No Program Selected")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Choose a program to see your\ndaily workout here.")
                        .font(.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            VStack(spacing: 12) {
                Button {
                    showProgramSelector = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                        Text("Find My Program")
                            .fontWeight(.bold)
                    }
                }
                .athleanButtonStyle()
                .padding(.horizontal, 40)

                NavigationLink(destination: ProgramLibraryView()) {
                    Text("Browse All Programs")
                        .font(.subheadline.bold())
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Main today content (program is active)

    private var todayContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                todayHeader
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                if let workout = viewModel.todayWorkout {
                    switch workout.type {
                    case .workout:
                        workoutHeroCard(workout)
                            .padding(.horizontal)
                        exercisePreviewList(workout)
                            .padding(.top, 16)
                        startWorkoutButton(workout)
                            .padding(.horizontal)
                            .padding(.top, 16)
                    case .rest, .active_recovery:
                        restDayCard(workout)
                            .padding(.horizontal)
                    }
                } else {
                    noWorkoutCard
                        .padding(.horizontal)
                }

                weekProgressSection
                    .padding(.horizontal)
                    .padding(.top, 28)

                quickActionsSection
                    .padding(.horizontal)
                    .padding(.top, 28)

                if !viewModel.recentHistory.isEmpty {
                    recentActivitySection
                        .padding(.horizontal)
                        .padding(.top, 28)
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Today header

    private var todayHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Constants.Colors.textSecondary)
                    .tracking(1.5)
                Text("Today")
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.white)
            }
            Spacer()
            if let program = viewModel.activeProgram {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("WEEK \(program.currentWeek)  DAY \(program.currentDay)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Constants.Colors.athleanRed)
                        .tracking(1)
                    Text(program.name)
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Workout hero card

    private func workoutHeroCard(_ workout: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Muscle groups targeted
            if let muscles = primaryMuscles(for: workout) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(muscles, id: \.self) { muscle in
                            Text(muscle)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Constants.Colors.athleanRed)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Constants.Colors.athleanRed.opacity(0.12))
                                .cornerRadius(20)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(2)
                if let notes = workout.notes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 20) {
                metaPill(icon: "list.number", value: "\(workout.exercises.count)", label: "exercises")
                metaPill(icon: "clock", value: "\(workout.estimatedDuration)", label: "min")
                metaPill(
                    icon: "flame.fill",
                    value: "\(workout.exercises.flatMap { $0.sets }.count)",
                    label: "sets",
                    color: .orange
                )
                if workout.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done")
                            .font(.caption.bold())
                    }
                    .foregroundColor(Constants.Colors.success)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "#1C1C1E"), Constants.Colors.cardBackground],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Constants.Colors.athleanRed.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Exercise preview list

    private func exercisePreviewList(_ workout: WorkoutDay) -> some View {
        let preview = Array(workout.exercises.prefix(4))
        let remaining = max(0, workout.exercises.count - 4)

        return VStack(spacing: 0) {
            ForEach(preview.indices, id: \.self) { i in
                let we = preview[i]
                HStack(spacing: 14) {
                    // Set number bubbles
                    HStack(spacing: 3) {
                        ForEach(0..<min(we.sets.count, 5), id: \.self) { _ in
                            Circle()
                                .fill(Constants.Colors.athleanRed.opacity(0.5))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(width: 42, alignment: .leading)

                    Text(we.exercise.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    if let firstSet = we.sets.first {
                        Text("\(we.sets.count)×\(firstSet.targetReps)")
                            .font(.caption.bold())
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 16)

                if i < preview.count - 1 || remaining > 0 {
                    Divider()
                        .background(Constants.Colors.secondaryBackground)
                        .padding(.horizontal, 16)
                }
            }

            if remaining > 0 {
                HStack {
                    Text("+\(remaining) more exercise\(remaining == 1 ? "" : "s")")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
        }
        .background(Constants.Colors.cardBackground)
        .cornerRadius(14)
        .padding(.horizontal)
    }

    // MARK: - Start button

    private func startWorkoutButton(_ workout: WorkoutDay) -> some View {
        Button {
            appState.todayWorkout = workout
            appState.isWorkoutActive = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: workout.isCompleted ? "arrow.clockwise" : "play.fill")
                    .font(.headline)
                Text(workout.isCompleted ? "Repeat Workout" : "Start Workout")
                    .font(.headline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#E53935"), Color(hex: "#B71C1C")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(14)
            .shadow(color: Color(hex: "#E53935").opacity(0.35), radius: 10, y: 5)
        }
    }

    // MARK: - Rest day card

    private func restDayCard(_ workout: WorkoutDay) -> some View {
        HStack(spacing: 16) {
            Image(systemName: workout.type == .active_recovery ? "figure.walk" : "moon.zzz.fill")
                .font(.system(size: 32))
                .foregroundColor(Constants.Colors.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.displayName)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text(workout.type == .active_recovery
                     ? "Light activity only — protect your recovery."
                     : "Recovery is where the gains happen. Rest up.")
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .lineSpacing(3)
            }
        }
        .cardStyle()
    }

    // MARK: - No workout data yet

    private var noWorkoutCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(Constants.Colors.athleanRed)
            Text("Loading today's workout…")
                .font(.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Week progress

    private var weekProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WEEK PROGRESS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Constants.Colors.textSecondary)
                    .tracking(1.5)
                Spacer()
                if let stats = viewModel.weeklyStats {
                    Text("\(stats.workoutsCompleted) / \(stats.workoutsPlanned) workouts")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
            if let stats = viewModel.weeklyStats {
                WeekDayDots(
                    total: stats.workoutsPlanned,
                    completed: stats.workoutsCompleted
                )
                HStack(spacing: 20) {
                    statBadge(value: "\(stats.totalMinutes)m", label: "Active time", icon: "clock", color: .white)
                    statBadge(value: "\(stats.workoutsCompleted)", label: "Workouts done", icon: "checkmark.circle", color: Constants.Colors.success)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Quick actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK ACTIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1.5)
            HStack(spacing: 12) {
                NavigationLink(destination: AbGeneratorView().environmentObject(appState)) {
                    quickActionTile(icon: "bolt.fill", label: "Ab Generator", color: Constants.Colors.athleanRed)
                }
                .buttonStyle(.plain)
                NavigationLink(destination: ExerciseLibraryView()) {
                    quickActionTile(icon: "dumbbell.fill", label: "Exercises", color: Color.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickActionTile(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Constants.Colors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Recent activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ACTIVITY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1.5)
            VStack(spacing: 0) {
                ForEach(viewModel.recentHistory.prefix(4)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.workoutTitle)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(entry.date.relativeString)
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                        Spacer()
                        Text("\(entry.duration)m")
                            .font(.caption.bold())
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    if entry.id != viewModel.recentHistory.prefix(4).last?.id {
                        Divider().background(Constants.Colors.secondaryBackground).padding(.horizontal, 16)
                    }
                }
            }
            .background(Constants.Colors.cardBackground)
            .cornerRadius(14)
        }
    }

    // MARK: - Helpers

    private func metaPill(icon: String, value: String, label: String, color: Color = Constants.Colors.athleanRed) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Constants.Colors.textSecondary)
        }
    }

    private func statBadge(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(value).font(.subheadline.bold()).foregroundColor(.white)
            Text(label).font(.caption).foregroundColor(Constants.Colors.textSecondary)
        }
    }

    private func primaryMuscles(for workout: WorkoutDay) -> [String]? {
        let muscles = workout.exercises
            .flatMap { $0.exercise.primaryMuscles }
            .map { $0.displayName }
        let unique = Array(NSOrderedSet(array: muscles)) as? [String]
        return unique?.isEmpty == false ? unique : nil
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 8) {
                AthleanLogoMark(size: 28)
                Text("ATHLEAN-X")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)
                    .tracking(2)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink(destination: ProfileView().environmentObject(authViewModel)) {
                Circle()
                    .fill(Constants.Colors.athleanRed)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(authViewModel.email.prefix(1).uppercased())
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

// MARK: - Week day progress dots

struct WeekDayDots: View {
    let total: Int
    let completed: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < completed ? Constants.Colors.athleanRed : Constants.Colors.secondaryBackground)
                    .frame(height: 6)
                    .animation(.easeInOut(duration: 0.3).delay(Double(i) * 0.05), value: completed)
            }
        }
    }
}

// MARK: - Program extension for current week/day

extension Program {
    var currentWeek: Int { 1 }  // populated from active program API response
    var currentDay: Int { 1 }
}
