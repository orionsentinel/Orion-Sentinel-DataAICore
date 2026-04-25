import Foundation

final class NutritionService {
    static let shared = NutritionService()
    private init() {}

    func fetchMealPlan(for goal: FitnessGoal) async throws -> MealPlan {
        try await APIClient.shared.request(.get("/nutrition/meal-plans", queryItems: [
            URLQueryItem(name: "goal", value: goal.rawValue)
        ]))
    }

    func fetchMealPlans() async throws -> [MealPlan] {
        try await APIClient.shared.request(.get("/nutrition/meal-plans"))
    }

    func fetchFoodSwaps(for foodItemId: Int) async throws -> [FoodItem] {
        try await APIClient.shared.request(.get("/nutrition/foods/\(foodItemId)/swaps"))
    }

    func logMeal(meal: Meal, date: Date) async throws -> NutritionLog {
        struct LogRequest: Encodable {
            let mealId: Int
            let date: Date
        }
        return try await APIClient.shared.request(
            .post("/nutrition/logs", body: LogRequest(mealId: meal.id, date: date))
        )
    }

    func fetchNutritionLog(for date: Date) async throws -> NutritionLog? {
        let dateString = DateFormatter.iso8601Date.string(from: date)
        return try? await APIClient.shared.request(
            .get("/nutrition/logs", queryItems: [URLQueryItem(name: "date", value: dateString)])
        )
    }

    func fetchNutritionHistory(days: Int = 7) async throws -> [NutritionLog] {
        try await APIClient.shared.request(
            .get("/nutrition/logs/history", queryItems: [URLQueryItem(name: "days", value: "\(days)")])
        )
    }
}

extension DateFormatter {
    static let iso8601Date: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
