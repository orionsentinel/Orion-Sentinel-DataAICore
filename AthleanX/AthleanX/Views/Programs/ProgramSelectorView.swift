import SwiftUI

struct ProgramSelectorView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ProgramViewModel()
    @State private var currentStep = 0
    @State private var selectedGoal: FitnessGoal?
    @State private var selectedDifficulty: Program.Difficulty?
    @State private var selectedEquipment: Equipment?
    @State private var showResults = false

    private let steps = ["Your Goal", "Experience Level", "Equipment"]

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                VStack(spacing: 0) {
                    stepIndicator
                    if showResults {
                        resultsView
                    } else {
                        questionView
                    }
                }
            }
            .navigationTitle("Find Your Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(steps.indices, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? Constants.Colors.athleanRed : Constants.Colors.secondaryBackground)
                    .frame(height: 3)
                    .animation(.easeInOut, value: currentStep)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var questionView: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                Text("STEP \(currentStep + 1) OF \(steps.count)")
                    .font(.caption.bold())
                    .foregroundColor(Constants.Colors.textSecondary)
                    .tracking(1)
                Text(steps[currentStep])
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.top, 24)

            switch currentStep {
            case 0: goalGrid
            case 1: difficultyGrid
            case 2: equipmentGrid
            default: EmptyView()
            }

            Spacer()
        }
    }

    private var goalGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(FitnessGoal.allCases, id: \.self) { goal in
                selectorCard(
                    title: goal.displayName,
                    icon: goal.iconName,
                    isSelected: selectedGoal == goal
                ) {
                    selectedGoal = goal
                    advance()
                }
            }
        }
        .padding(.horizontal)
    }

    private var difficultyGrid: some View {
        VStack(spacing: 12) {
            ForEach(Program.Difficulty.allCases, id: \.self) { diff in
                selectorRow(
                    title: diff.displayName,
                    subtitle: difficultySubtitle(diff),
                    color: Color(hex: diff.color),
                    isSelected: selectedDifficulty == diff
                ) {
                    selectedDifficulty = diff
                    advance()
                }
            }
        }
        .padding(.horizontal)
    }

    private var equipmentGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach([Equipment.bodyweightOnly, .pullupBar, .dumbbell, .fullGym], id: \.self) { eq in
                selectorCard(
                    title: eq.displayName,
                    icon: equipmentIcon(eq),
                    isSelected: selectedEquipment == eq
                ) {
                    selectedEquipment = eq
                    advance()
                }
            }
        }
        .padding(.horizontal)
    }

    private var resultsView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Constants.Colors.athleanRed)
                Text("Your Matches")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)
                Text("Based on your answers")
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            .padding(.top, 24)

            if viewModel.isLoading {
                ProgressView().tint(Constants.Colors.athleanRed)
                    .scaleEffect(1.5)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.filteredPrograms.prefix(5)) { program in
                            NavigationLink(destination: ProgramDetailView(program: program)) {
                                ProgramRow(program: program)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            viewModel.filter = ProgramFilter(goal: selectedGoal, difficulty: selectedDifficulty, equipment: selectedEquipment)
            await viewModel.loadPrograms()
        }
    }

    private func selectorCard(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Constants.Colors.textSecondary)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? .white : Constants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? Constants.Colors.athleanRed : Constants.Colors.cardBackground)
            .cornerRadius(Constants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(isSelected ? Constants.Colors.athleanRed : Color.clear, lineWidth: 2)
            )
        }
    }

    private func selectorRow(title: String, subtitle: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Constants.Colors.athleanRed)
                }
            }
            .padding()
            .background(isSelected ? Constants.Colors.athleanRed.opacity(0.15) : Constants.Colors.cardBackground)
            .cornerRadius(Constants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(isSelected ? Constants.Colors.athleanRed : Color.clear, lineWidth: 1.5)
            )
        }
    }

    private func advance() {
        if currentStep < steps.count - 1 {
            withAnimation { currentStep += 1 }
        } else {
            withAnimation { showResults = true }
        }
    }

    private func difficultySubtitle(_ diff: Program.Difficulty) -> String {
        switch diff {
        case .beginner: return "New to structured training"
        case .intermediate: return "6+ months of consistent training"
        case .advanced: return "2+ years, solid foundations"
        case .elite: return "Competitive athlete level"
        }
    }

    private func equipmentIcon(_ eq: Equipment) -> String {
        switch eq {
        case .bodyweightOnly: return "figure.gymnastics"
        case .pullupBar: return "arrow.up.to.line"
        case .dumbbell: return "dumbbell.fill"
        case .fullGym: return "building.2.fill"
        default: return "dumbbell.fill"
        }
    }
}
