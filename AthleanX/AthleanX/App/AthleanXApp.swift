import SwiftUI
import UserNotifications

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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var activeProgram: Program?
    @Published var todayWorkout: WorkoutDay?
    @Published var isWorkoutActive = false

    init() {
        // Restore cached state so first render is immediate
        activeProgram = CacheService.shared.loadActiveProgram()
        todayWorkout = CacheService.shared.loadTodayWorkout()
    }
}
