import Foundation
import Combine

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var mealPlans: [MealPlan] = []
    @Published var activeMealPlan: MealPlan?
    @Published var todayLog: NutritionLog?
    @Published var selectedGoal: FitnessGoal = .buildMuscle
    @Published var isLoading = false
    @Published var errorMessage: String?

    var caloriesConsumedToday: Int { todayLog?.totalCalories ?? 0 }

    var caloriesRemainingToday: Int {
        (activeMealPlan?.calories ?? 0) - caloriesConsumedToday
    }

    var macroProgress: MacroProgress? {
        guard let plan = activeMealPlan else { return nil }
        let logged = todayLog?.loggedMeals ?? []
        return MacroProgress(
            protein: MacroProgress.Macro(
                consumed: logged.flatMap { $0.foods }.reduce(0) { $0 + $1.protein },
                target: Double(plan.macros.protein)
            ),
            carbs: MacroProgress.Macro(
                consumed: logged.flatMap { $0.foods }.reduce(0) { $0 + $1.carbs },
                target: Double(plan.macros.carbs)
            ),
            fat: MacroProgress.Macro(
                consumed: logged.flatMap { $0.foods }.reduce(0) { $0 + $1.fat },
                target: Double(plan.macros.fat)
            )
        )
    }

    struct MacroProgress {
        let protein: Macro
        let carbs: Macro
        let fat: Macro

        struct Macro {
            let consumed: Double
            let target: Double
            var percentage: Double { target > 0 ? min(consumed / target, 1.0) : 0 }
        }
    }

    func loadNutrition() async {
        isLoading = true
        async let plansTask = NutritionService.shared.fetchMealPlans()
        async let logTask = NutritionService.shared.fetchNutritionLog(for: Date())

        do {
            let (plans, log) = try await (plansTask, logTask)
            mealPlans = plans
            activeMealPlan = plans.first(where: { $0.goal == selectedGoal }) ?? plans.first
            todayLog = log
        } catch {
            errorMessage = "Failed to load nutrition data."
        }
        isLoading = false
    }

    func logMeal(_ meal: Meal) async {
        do {
            todayLog = try await NutritionService.shared.logMeal(meal: meal, date: Date())
        } catch {
            errorMessage = "Failed to log meal."
        }
    }

    func switchGoal(_ goal: FitnessGoal) async {
        selectedGoal = goal
        isLoading = true
        do {
            activeMealPlan = try await NutritionService.shared.fetchMealPlan(for: goal)
        } catch {
            errorMessage = "Failed to load meal plan."
        }
        isLoading = false
    }
}
