import SwiftUI

struct NutritionView: View {
    @StateObject private var viewModel = NutritionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                if viewModel.isLoading && viewModel.activeMealPlan == nil {
                    ProgressView().tint(Constants.Colors.athleanRed)
                } else {
                    content
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadNutrition() }
            .refreshable { await viewModel.loadNutrition() }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.UI.sectionSpacing) {
                goalSelector
                if let plan = viewModel.activeMealPlan {
                    caloriesCard(plan: plan)
                    macroCard
                    mealsSection(plan: plan)
                }
            }
            .padding()
        }
    }

    private var goalSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FitnessGoal.allCases, id: \.self) { goal in
                    Button {
                        Task { await viewModel.switchGoal(goal) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: goal.iconName).font(.caption)
                            Text(goal.displayName).font(.caption.bold())
                        }
                        .foregroundColor(viewModel.selectedGoal == goal ? .white : Constants.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedGoal == goal
                                    ? Constants.Colors.athleanRed
                                    : Constants.Colors.cardBackground)
                        .cornerRadius(20)
                    }
                }
            }
        }
    }

    private func caloriesCard(plan: MealPlan) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY CALORIES")
                        .font(.caption.bold())
                        .foregroundColor(Constants.Colors.textSecondary)
                        .tracking(1)
                    Text("\(viewModel.caloriesConsumedToday)")
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(.white)
                        +
                        Text(" / \(plan.calories)")
                        .font(.title3)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                Spacer()
                CalorieRing(
                    consumed: viewModel.caloriesConsumedToday,
                    target: plan.calories
                )
                .frame(width: 64, height: 64)
            }

            ProgressView(value: Double(viewModel.caloriesConsumedToday) / Double(plan.calories))
                .tint(calorieColor)
                .background(Constants.Colors.secondaryBackground)
                .cornerRadius(4)

            HStack {
                Text("\(viewModel.caloriesRemainingToday) kcal remaining")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
                Spacer()
            }
        }
        .cardStyle()
    }

    private var calorieColor: Color {
        let ratio = Double(viewModel.caloriesConsumedToday) / Double(viewModel.activeMealPlan?.calories ?? 1)
        if ratio > 1.05 { return .red }
        if ratio > 0.9 { return Constants.Colors.success }
        return Constants.Colors.athleanRed
    }

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MACROS")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            if let macros = viewModel.macroProgress {
                macroRow("Protein", value: macros.protein, color: Color(hex: "#D0021B"))
                macroRow("Carbs", value: macros.carbs, color: Color(hex: "#F5A623"))
                macroRow("Fat", value: macros.fat, color: Color(hex: "#9B59B6"))
            }
        }
        .cardStyle()
    }

    private func macroRow(_ name: String, value: NutritionViewModel.MacroProgress.Macro, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(value.consumed))g / \(Int(value.target))g")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            ProgressView(value: value.percentage)
                .tint(color)
                .background(Constants.Colors.secondaryBackground)
                .cornerRadius(4)
        }
    }

    private func mealsSection(plan: MealPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S MEALS")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            ForEach(plan.meals) { meal in
                NavigationLink(destination: MealDetailView(meal: meal, viewModel: viewModel)) {
                    MealCard(meal: meal, isLogged: viewModel.todayLog?.loggedMeals.contains(where: { $0.mealName == meal.name }) ?? false)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CalorieRing: View {
    let consumed: Int
    let target: Int

    var progress: Double { min(Double(consumed) / Double(target), 1.0) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Constants.Colors.secondaryBackground, lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Constants.Colors.athleanRed, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct MealCard: View {
    let meal: Meal
    let isLogged: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.time.uppercased())
                    .font(.caption2.bold())
                    .foregroundColor(Constants.Colors.athleanRed)
                    .tracking(1)
                Text(meal.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("\(meal.totalCalories) kcal · \(meal.foods.count) foods")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            Spacer()
            if isLogged {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Constants.Colors.success)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(Constants.Colors.textSecondary)
                    .font(.caption)
            }
        }
        .cardStyle()
    }
}

struct MealDetailView: View {
    let meal: Meal
    @ObservedObject var viewModel: NutritionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isLogging = false

    var body: some View {
        ZStack {
            Constants.Colors.athleanDark.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.time.uppercased())
                            .font(.caption.bold())
                            .foregroundColor(Constants.Colors.athleanRed)
                            .tracking(1)
                        Text(meal.name)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("\(meal.totalCalories) kcal")
                            .font(.subheadline)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 2) {
                        ForEach(meal.foods) { food in
                            FoodRow(food: food)
                        }
                    }

                    Button {
                        Task {
                            isLogging = true
                            await viewModel.logMeal(meal)
                            isLogging = false
                            dismiss()
                        }
                    } label: {
                        if isLogging {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log This Meal")
                        }
                    }
                    .athleanButtonStyle()
                    .padding(.horizontal)
                    .disabled(isLogging)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(meal.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FoodRow: View {
    let food: FoodItem

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: food.category.colorHex))
                .frame(width: 8, height: 8)
            Text(food.name)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Text(food.serving)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
            Text("\(food.calories) kcal")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Constants.Colors.cardBackground)
    }
}
