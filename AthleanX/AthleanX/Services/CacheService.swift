import Foundation

final class CacheService {
    static let shared = CacheService()
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder.athlean
    private let decoder = JSONDecoder.athlean
    private init() {}

    private enum Key {
        static let programs = "cache.programs"
        static let exercises = "cache.exercises"
        static let activeProgram = "cache.activeProgram"
        static let todayWorkout = "cache.todayWorkout"
        static let mealPlans = "cache.mealPlans"
        static let programsTimestamp = "cache.programs.ts"
        static let exercisesTimestamp = "cache.exercises.ts"
    }

    private let ttl: TimeInterval = Constants.Cache.cacheExpiryHours * 3600

    func savePrograms(_ programs: [Program]) {
        save(programs, key: Key.programs, timestampKey: Key.programsTimestamp)
    }

    func loadPrograms() -> [Program]? {
        load(key: Key.programs, timestampKey: Key.programsTimestamp)
    }

    func saveExercises(_ exercises: [Exercise]) {
        save(exercises, key: Key.exercises, timestampKey: Key.exercisesTimestamp)
    }

    func loadExercises() -> [Exercise]? {
        load(key: Key.exercises, timestampKey: Key.exercisesTimestamp)
    }

    func saveActiveProgram(_ program: Program?) {
        guard let program else {
            defaults.removeObject(forKey: Key.activeProgram)
            return
        }
        defaults.set(try? encoder.encode(program), forKey: Key.activeProgram)
    }

    func loadActiveProgram() -> Program? {
        guard let data = defaults.data(forKey: Key.activeProgram) else { return nil }
        return try? decoder.decode(Program.self, from: data)
    }

    func saveTodayWorkout(_ workout: WorkoutDay?) {
        guard let workout else {
            defaults.removeObject(forKey: Key.todayWorkout)
            return
        }
        let key = Key.todayWorkout + "." + Date().formatted("yyyy-MM-dd")
        defaults.set(try? encoder.encode(workout), forKey: key)
    }

    func loadTodayWorkout() -> WorkoutDay? {
        let key = Key.todayWorkout + "." + Date().formatted("yyyy-MM-dd")
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(WorkoutDay.self, from: data)
    }

    func saveMealPlans(_ plans: [MealPlan]) {
        save(plans, key: Key.mealPlans, timestampKey: nil)
    }

    func loadMealPlans() -> [MealPlan]? {
        guard let data = defaults.data(forKey: Key.mealPlans) else { return nil }
        return try? decoder.decode([MealPlan].self, from: data)
    }

    func clearAll() {
        [Key.programs, Key.exercises, Key.activeProgram, Key.todayWorkout, Key.mealPlans,
         Key.programsTimestamp, Key.exercisesTimestamp].forEach {
            defaults.removeObject(forKey: $0)
        }
    }

    private func save<T: Encodable>(_ value: T, key: String, timestampKey: String?) {
        defaults.set(try? encoder.encode(value), forKey: key)
        if let tsKey = timestampKey {
            defaults.set(Date().timeIntervalSince1970, forKey: tsKey)
        }
    }

    private func load<T: Decodable>(key: String, timestampKey: String?) -> T? {
        if let tsKey = timestampKey {
            let ts = defaults.double(forKey: tsKey)
            guard ts > 0, Date().timeIntervalSince1970 - ts < ttl else { return nil }
        }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}
