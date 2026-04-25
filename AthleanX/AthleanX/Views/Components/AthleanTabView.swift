import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            ProgramLibraryView()
                .tabItem {
                    Label("Programs", systemImage: "list.bullet.clipboard")
                }
                .tag(1)

            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: selectedTab == 2 ? "fork.knife.circle.fill" : "fork.knife.circle")
                }
                .tag(2)

            ExerciseLibraryView()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell.fill")
                }
                .tag(3)

            ProgressTrackingView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(4)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: selectedTab == 5 ? "person.fill" : "person")
                }
                .tag(5)
        }
        .tint(Constants.Colors.athleanRed)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $appState.isWorkoutActive) {
            if let workout = appState.todayWorkout {
                ActiveWorkoutView(workoutDay: workout)
                    .environmentObject(appState)
            }
        }
    }
}
