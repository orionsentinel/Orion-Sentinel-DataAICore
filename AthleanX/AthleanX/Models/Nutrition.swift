import Foundation

struct MealPlan: Codable, Identifiable {
    let id: Int
    let name: String
    let goal: FitnessGoal
    let calories: Int
    let macros: Macros
    let meals: [Meal]
    let notes: String?

    struct Macros: Codable {
        let protein: Int // grams
        let carbs: Int
        let fat: Int
    }
}

struct Meal: Codable, Identifiable {
    let id: Int
    let name: String
    let time: String // "Breakfast", "Pre-Workout", etc.
    let foods: [FoodItem]

    var totalCalories: Int { foods.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { foods.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double { foods.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { foods.reduce(0) { $0 + $1.fat } }
}

struct FoodItem: Codable, Identifiable {
    let id: Int
    let name: String
    let category: FoodCategory
    let serving: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let swapOptions: [FoodItem]?

    enum FoodCategory: String, Codable {
        case starchyCarbs = "starchy_carbs"
        case fibrousCarbs = "fibrous_carbs"
        case protein
        case fat

        var displayName: String {
            switch self {
            case .starchyCarbs: return "Starchy Carbs"
            case .fibrousCarbs: return "Fibrous Carbs"
            case .protein: return "Protein"
            case .fat: return "Fat"
            }
        }

        var colorHex: String {
            switch self {
            case .starchyCarbs: return "#F5A623"
            case .fibrousCarbs: return "#7ED321"
            case .protein: return "#D0021B"
            case .fat: return "#9B59B6"
            }
        }
    }
}

struct NutritionLog: Codable, Identifiable {
    let id: UUID
    let date: Date
    var loggedMeals: [LoggedMeal]

    var totalCalories: Int { loggedMeals.reduce(0) { $0 + $1.calories } }

    init(date: Date) {
        self.id = UUID()
        self.date = date
        self.loggedMeals = []
    }
}

struct LoggedMeal: Codable, Identifiable {
    let id: UUID
    let mealName: String
    let foods: [FoodItem]
    let loggedAt: Date
    let calories: Int

    init(meal: Meal) {
        self.id = UUID()
        self.mealName = meal.name
        self.foods = meal.foods
        self.loggedAt = Date()
        self.calories = meal.totalCalories
    }
}
