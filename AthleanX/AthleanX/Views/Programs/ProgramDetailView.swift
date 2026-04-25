import SwiftUI

struct ProgramDetailView: View {
    let program: Program
    @StateObject private var viewModel = ProgramViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedWeekIndex = 0
    @State private var showEnrollConfirmation = false

    var body: some View {
        ZStack {
            Constants.Colors.athleanDark.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    detailContent
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack {
                Spacer()
                enrollButton
                    .padding()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }
        }
        .alert("Start Program", isPresented: $showEnrollConfirmation) {
            Button("Let's Go!", role: .none) {
                Task { await viewModel.enrollInProgram(program) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will set \(program.name) as your active program. Ready to get after it?")
        }
        .overlay {
            if let msg = viewModel.enrollSuccessMessage {
                enrollSuccessOverlay(msg)
            }
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: program.thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Constants.Colors.secondaryBackground
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()

            LinearGradient(
                colors: [Constants.Colors.athleanDark, .clear],
                startPoint: .bottom, endPoint: .center
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(program.name)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                programMetaBadges
            }
            .padding()
        }
    }

    private var programMetaBadges: some View {
        HStack(spacing: 8) {
            metaBadge(icon: "clock", text: "\(program.duration) weeks")
            metaBadge(icon: "calendar", text: "\(program.daysPerWeek)x/week")
            Text(program.difficulty.displayName)
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: program.difficulty.color))
                .cornerRadius(6)
        }
    }

    private func metaBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption)
            Text(text).font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.5))
        .cornerRadius(6)
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(program.description)
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .lineSpacing(4)

            goalsSection
            equipmentSection
            weeklyBreakdownSection

            Spacer(minLength: 80)
        }
        .padding()
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("GOALS")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(program.goals, id: \.self) { goal in
                    HStack(spacing: 6) {
                        Image(systemName: goal.iconName)
                            .foregroundColor(Constants.Colors.athleanRed)
                        Text(goal.displayName)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Constants.Colors.cardBackground)
                    .cornerRadius(8)
                }
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("EQUIPMENT NEEDED")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(program.equipment, id: \.self) { item in
                        Text(item.displayName)
                            .font(.caption.bold())
                            .foregroundColor(Constants.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Constants.Colors.cardBackground)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var weeklyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("WEEKLY BREAKDOWN")
            if !program.weeks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(program.weeks.indices, id: \.self) { i in
                            Button {
                                selectedWeekIndex = i
                            } label: {
                                Text("Week \(i + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(selectedWeekIndex == i ? .white : Constants.Colors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedWeekIndex == i
                                                ? Constants.Colors.athleanRed
                                                : Constants.Colors.cardBackground)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                if selectedWeekIndex < program.weeks.count {
                    VStack(spacing: 6) {
                        ForEach(program.weeks[selectedWeekIndex].days) { day in
                            DayRow(day: day)
                        }
                    }
                }
            }
        }
    }

    private var enrollButton: some View {
        Button {
            showEnrollConfirmation = true
        } label: {
            if viewModel.isEnrolling {
                ProgressView().tint(.white)
            } else {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start This Program")
                        .fontWeight(.bold)
                }
            }
        }
        .disabled(viewModel.isEnrolling)
        .athleanButtonStyle()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundColor(Constants.Colors.textSecondary)
            .tracking(1)
    }

    private func enrollSuccessOverlay(_ message: String) -> some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Constants.Colors.success)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Constants.Colors.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct DayRow: View {
    let day: WorkoutDay

    var body: some View {
        HStack {
            Circle()
                .fill(day.type == .rest ? Constants.Colors.secondaryBackground : Constants.Colors.athleanRed.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("D\(day.dayNumber)")
                        .font(.caption.bold())
                        .foregroundColor(day.type == .rest ? Constants.Colors.textSecondary : Constants.Colors.athleanRed)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(day.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                if day.type == .workout {
                    Text("\(day.exercises.count) exercises · \(day.estimatedDuration) min")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
            Spacer()
            if day.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Constants.Colors.success)
                    .font(.caption)
            }
        }
        .padding(10)
        .background(Constants.Colors.cardBackground)
        .cornerRadius(8)
    }
}
