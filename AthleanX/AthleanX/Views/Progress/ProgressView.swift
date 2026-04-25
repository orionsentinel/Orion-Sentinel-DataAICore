import SwiftUI
import Charts

struct ProgressTrackingView: View {
    @StateObject private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                if viewModel.isLoading && viewModel.workoutHistory.isEmpty {
                    ProgressView().tint(Constants.Colors.athleanRed)
                } else {
                    content
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingAddEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Constants.Colors.athleanRed)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddEntry) {
                AddProgressEntryView(viewModel: viewModel)
            }
            .task { await viewModel.loadProgress() }
            .refreshable { await viewModel.loadProgress() }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.UI.sectionSpacing) {
                statsRow
                if !viewModel.weightHistory.isEmpty {
                    weightChart
                }
                workoutHistorySection
                if !viewModel.personalRecords.isEmpty {
                    personalRecordsSection
                }
            }
            .padding()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(viewModel.totalWorkoutsThisMonth)", label: "This Month", icon: "calendar.badge.checkmark")
            statCard(value: "\(viewModel.streakDays)", label: "Day Streak", icon: "flame.fill", color: .orange)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color = Constants.Colors.athleanRed) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    @ViewBuilder
    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEIGHT TREND")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            Chart(viewModel.weightHistory, id: \.0) { entry in
                LineMark(
                    x: .value("Date", entry.0),
                    y: .value("Weight", entry.1)
                )
                .foregroundStyle(Constants.Colors.athleanRed)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Date", entry.0),
                    y: .value("Weight", entry.1)
                )
                .foregroundStyle(Constants.Colors.athleanRed.opacity(0.1))
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(Constants.Colors.secondaryBackground)
                    AxisValueLabel().foregroundStyle(Constants.Colors.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(Constants.Colors.secondaryBackground)
                    AxisValueLabel().foregroundStyle(Constants.Colors.textSecondary)
                }
            }
        }
        .cardStyle()
    }

    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKOUT HISTORY")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            ForEach(viewModel.workoutHistory.prefix(10)) { entry in
                WorkoutHistoryRow(entry: entry)
            }
        }
    }

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERSONAL RECORDS")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)

            ForEach(viewModel.personalRecords.prefix(5)) { pr in
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(pr.exerciseName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(pr.weight)) lbs × \(pr.reps)")
                        .font(.subheadline.bold())
                        .foregroundColor(Constants.Colors.athleanRed)
                }
                .padding(.vertical, 6)
                if pr.id != viewModel.personalRecords.prefix(5).last?.id {
                    Divider().background(Constants.Colors.secondaryBackground)
                }
            }
        }
        .cardStyle()
    }
}

struct WorkoutHistoryRow: View {
    let entry: WorkoutHistory

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.workoutTitle)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(entry.date.relativeString)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.duration)m")
                    .font(.subheadline.bold())
                    .foregroundColor(Constants.Colors.athleanRed)
                Text("\(entry.exerciseLogs.count) exercises")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
        }
        .padding(.vertical, 6)
        if entry.id != entry.id { Divider() }
    }
}

struct AddProgressEntryView: View {
    @ObservedObject var viewModel: ProgressViewModel
    @Environment(\.dismiss) var dismiss
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                Form {
                    Section("BODY METRICS") {
                        HStack {
                            Text("Weight (lbs)")
                                .foregroundColor(.white)
                            Spacer()
                            TextField("0.0", text: $weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Constants.Colors.athleanRed)
                        }
                        HStack {
                            Text("Body Fat %")
                                .foregroundColor(.white)
                            Spacer()
                            TextField("0.0", text: $bodyFat)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Constants.Colors.athleanRed)
                        }
                    }
                    .listRowBackground(Constants.Colors.cardBackground)

                    Section("NOTES") {
                        TextField("How are you feeling?", text: $notes, axis: .vertical)
                            .foregroundColor(.white)
                            .lineLimit(3...6)
                    }
                    .listRowBackground(Constants.Colors.cardBackground)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Log Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let entry = ProgressEntry(
                            id: UUID(),
                            date: Date(),
                            weight: Double(weight),
                            bodyFatPercentage: Double(bodyFat),
                            measurements: nil,
                            photos: [],
                            notes: notes.isEmpty ? nil : notes
                        )
                        viewModel.addProgressEntry(entry)
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.athleanRed)
                    .fontWeight(.bold)
                }
            }
        }
    }
}
