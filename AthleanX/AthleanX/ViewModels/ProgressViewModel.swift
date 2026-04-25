import Foundation
import UIKit

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published var workoutHistory: [WorkoutHistory] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var progressEntries: [ProgressEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddEntry = false

    private static let entriesKey = "progress.entries.v1"

    var weightHistory: [(Date, Double)] {
        progressEntries.compactMap { entry in
            guard let weight = entry.weight else { return nil }
            return (entry.date, weight)
        }.sorted { $0.0 < $1.0 }
    }

    var totalWorkoutsThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return workoutHistory.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    var totalVolumeThisWeek: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return workoutHistory
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.totalVolume }
    }

    var streakDays: Int {
        var streak = 0
        var checkDate = Date()
        let calendar = Calendar.current
        for _ in 0..<365 {
            let dayWorkouts = workoutHistory.filter {
                calendar.isDate($0.date, equalTo: checkDate, toGranularity: .day)
            }
            if dayWorkouts.isEmpty { break }
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    init() {
        loadPersistedEntries()
    }

    func loadProgress() async {
        isLoading = true
        async let historyTask = WorkoutService.shared.fetchWorkoutHistory(page: 1, limit: 50)
        async let prTask = WorkoutService.shared.fetchPersonalRecords()
        do {
            let (history, prs) = try await (historyTask, prTask)
            workoutHistory = history
            personalRecords = prs
        } catch {
            errorMessage = "Failed to load progress data."
        }
        isLoading = false
    }

    func addProgressEntry(_ entry: ProgressEntry) {
        progressEntries.append(entry)
        progressEntries.sort { $0.date > $1.date }
        persistEntries()
    }

    func deleteProgressEntry(id: UUID) {
        if let entry = progressEntries.first(where: { $0.id == id }) {
            for photo in entry.photos {
                Self.deleteProgressPhoto(photo.localPath)
            }
        }
        progressEntries.removeAll { $0.id == id }
        persistEntries()
    }

    // MARK: - Persistence

    private func loadPersistedEntries() {
        guard let data = UserDefaults.standard.data(forKey: Self.entriesKey),
              let entries = try? JSONDecoder.athlean.decode([ProgressEntry].self, from: data) else { return }
        progressEntries = entries
    }

    private func persistEntries() {
        guard let data = try? JSONEncoder.athlean.encode(progressEntries) else { return }
        UserDefaults.standard.set(data, forKey: Self.entriesKey)
    }

    // MARK: - Photo storage

    private static var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("ProgressPhotos", isDirectory: true)
    }

    static func saveProgressPhoto(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let dir = photosDirectory
        let url = dir.appendingPathComponent(filename)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func loadProgressPhoto(_ filename: String) -> UIImage? {
        let url = photosDirectory.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    private static func deleteProgressPhoto(_ filename: String) {
        let url = photosDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
