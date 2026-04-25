import Foundation
import UserNotifications

final class WorkoutReminderService {
    static let shared = WorkoutReminderService()
    private init() {}

    private let reminderCategoryId = "WORKOUT_REMINDER"
    private let reminderIdentifierPrefix = "athleanx.workout.reminder."

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleDaily(at hour: Int, minute: Int, workoutName: String?) async {
        await cancelAll()
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Train"
        content.body = workoutName.map { "Your workout \"\($0)\" is ready." }
            ?? "ATHLEAN-X is waiting. Get after it."
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = reminderCategoryId

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: reminderIdentifierPrefix + "daily",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func scheduleWorkoutComplete(workoutTitle: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Workout Logged!"
        content.body = "\"\(workoutTitle)\" saved. Recovery starts now."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminderIdentifierPrefix + "complete.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .filter { $0.identifier.hasPrefix(reminderIdentifierPrefix) }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
