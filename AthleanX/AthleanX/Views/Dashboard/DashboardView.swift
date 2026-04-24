import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                if viewModel.isLoading && viewModel.activeProgram == nil {
                    loadingView
                } else {
                    content
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .refreshable { await viewModel.loadDashboard() }
            .task { await viewModel.loadDashboard() }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.UI.sectionSpacing) {
                greetingHeader
                if let workout = viewModel.todayWorkout {
                    todayWorkoutCard(workout)
                } else {
                    restDayCard
                }
                if let stats = viewModel.weeklyStats {
                    weeklyStatsSection(stats)
                }
                if !viewModel.recentHistory.isEmpty {
                    recentActivitySection
                }
            }
            .padding()
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
            Text(authViewModel.currentUser?.firstName ?? "Athlete")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.white)
            if let program = viewModel.activeProgram {
                Text(program.name)
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.athleanRed)
            }
        }
    }

    private func todayWorkoutCard(_ workout: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S WORKOUT")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.textSecondary)
                        .tracking(1)
                    Text(workout.title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(workout.estimatedDuration) min")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.athleanRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Constants.Colors.athleanRed.opacity(0.15))
                    .cornerRadius(6)
            }

            HStack(spacing: 20) {
                statBadge(value: "\(workout.exercises.count)", label: "Exercises")
                statBadge(value: "\(workout.exercises.flatMap { $0.sets }.count)", label: "Sets")
                if workout.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.success)
                }
            }

            Button {
                appState.todayWorkout = workout
                appState.isWorkoutActive = true
            } label: {
                HStack {
                    Image(systemName: workout.isCompleted ? "arrow.clockwise" : "play.fill")
                    Text(workout.isCompleted ? "Repeat Workout" : "Start Workout")
                        .fontWeight(.bold)
                }
            }
            .athleanButtonStyle()
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .stroke(Constants.Colors.athleanRed.opacity(0.3), lineWidth: 1)
        )
    }

    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 32))
                .foregroundColor(Constants.Colors.textSecondary)
            Text("Rest Day")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Recovery is where gains happen. Take it easy today.")
                .font(.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func weeklyStatsSection(_ stats: DashboardViewModel.WeeklyStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS WEEK")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            HStack(spacing: 12) {
                weekStatCard(
                    value: "\(stats.workoutsCompleted)/\(stats.workoutsPlanned)",
                    label: "Workouts",
                    icon: "checkmark.circle",
                    color: Constants.Colors.success
                )
                weekStatCard(
                    value: "\(stats.totalMinutes)m",
                    label: "Active Time",
                    icon: "clock",
                    color: Constants.Colors.athleanRed
                )
            }

            ProgressView(value: stats.completionPercentage)
                .tint(Constants.Colors.athleanRed)
                .background(Constants.Colors.secondaryBackground)
                .cornerRadius(4)
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT ACTIVITY")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            ForEach(viewModel.recentHistory.prefix(3)) { entry in
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
                .padding(.vertical, 4)
                if entry.id != viewModel.recentHistory.prefix(3).last?.id {
                    Divider().background(Constants.Colors.secondaryBackground)
                }
            }
        }
        .cardStyle()
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(Constants.Colors.textSecondary)
        }
    }

    private func weekStatCard(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Constants.Colors.athleanRed)
                .scaleEffect(1.5)
            Text("Loading your workout...")
                .foregroundColor(Constants.Colors.textSecondary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Image(systemName: "bolt.fill")
                .foregroundColor(Constants.Colors.athleanRed)
                .font(.title3.bold())
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink(destination: ProfileView()) {
                if let url = authViewModel.currentUser?.avatarURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Constants.Colors.athleanRed)
            .frame(width: 32, height: 32)
            .overlay(
                Text(authViewModel.currentUser?.firstName.prefix(1).uppercased() ?? "A")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            )
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
