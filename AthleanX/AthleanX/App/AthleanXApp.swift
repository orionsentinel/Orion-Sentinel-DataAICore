import SwiftUI

@main
struct AthleanXApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    MainTabView()
                        .environmentObject(authViewModel)
                        .environmentObject(appState)
                } else {
                    OnboardingView()
                        .environmentObject(authViewModel)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

class AppState: ObservableObject {
    @Published var activeProgram: Program?
    @Published var todayWorkout: WorkoutDay?
    @Published var isWorkoutActive = false
}
