import SwiftUI

struct ProgramLibraryView: View {
    @StateObject private var viewModel = ProgramViewModel()
    @State private var showFilter = false
    @State private var showSelector = false

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                if viewModel.isLoading && viewModel.programs.isEmpty {
                    ProgressView().tint(Constants.Colors.athleanRed)
                } else if viewModel.programs.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.clipboard",
                        title: "No Programs Found",
                        message: "Programs will appear here once you're connected.",
                        actionTitle: "Refresh"
                    ) { Task { await viewModel.loadPrograms() } }
                } else {
                    programList
                }
            }
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSelector = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                            Text("Find Mine")
                                .font(.caption.bold())
                        }
                        .foregroundColor(Constants.Colors.athleanRed)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilter.toggle()
                    } label: {
                        Image(systemName: viewModel.filter.goal != nil || viewModel.filter.difficulty != nil
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                        .foregroundColor(Constants.Colors.athleanRed)
                    }
                }
            }
            .sheet(isPresented: $showFilter) {
                ProgramFilterSheet(filter: $viewModel.filter)
            }
            .sheet(isPresented: $showSelector) {
                ProgramSelectorView()
            }
            .task { await viewModel.loadPrograms() }
            .refreshable { await viewModel.loadPrograms() }
        }
    }

    private var programList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.UI.sectionSpacing) {
                if !viewModel.featuredPrograms.isEmpty && !viewModel.filter.isActive {
                    featuredSection
                }
                allProgramsSection
            }
            .padding()
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FEATURED")
                .font(.caption.bold())
                .foregroundColor(Constants.Colors.textSecondary)
                .tracking(1)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.featuredPrograms) { program in
                        NavigationLink(destination: ProgramDetailView(program: program)) {
                            FeaturedProgramCard(program: program)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var allProgramsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ALL PROGRAMS")
                    .font(.caption.bold())
                    .foregroundColor(Constants.Colors.textSecondary)
                    .tracking(1)
                Spacer()
                Text("\(viewModel.filteredPrograms.count) programs")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            ForEach(viewModel.filteredPrograms) { program in
                NavigationLink(destination: ProgramDetailView(program: program)) {
                    ProgramRow(program: program)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FeaturedProgramCard: View {
    let program: Program

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: program.thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Constants.Colors.cardBackground
            }
            .frame(width: 220, height: 140)
            .clipped()
            .cornerRadius(Constants.UI.cornerRadius)

            LinearGradient(
                colors: [.black.opacity(0.7), .clear],
                startPoint: .bottom, endPoint: .top
            )
            .cornerRadius(Constants.UI.cornerRadius)

            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("\(program.duration) weeks · \(program.daysPerWeek)x/week")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(12)
        }
        .frame(width: 220, height: 140)
    }
}

struct ProgramRow: View {
    let program: Program

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: program.thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Constants.Colors.secondaryBackground
            }
            .frame(width: 64, height: 64)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(program.shortDescription)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    difficultyBadge
                    Text("\(program.duration) weeks")
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .cardStyle()
    }

    private var difficultyBadge: some View {
        Text(program.difficulty.displayName)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: program.difficulty.color))
            .cornerRadius(4)
    }
}

struct ProgramFilterSheet: View {
    @Binding var filter: ProgramFilter
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.athleanDark.ignoresSafeArea()
                List {
                    Section("GOAL") {
                        ForEach(FitnessGoal.allCases, id: \.self) { goal in
                            filterRow(
                                title: goal.displayName,
                                icon: goal.iconName,
                                isSelected: filter.goal == goal
                            ) {
                                filter.goal = filter.goal == goal ? nil : goal
                            }
                        }
                    }
                    .listRowBackground(Constants.Colors.cardBackground)

                    Section("DIFFICULTY") {
                        ForEach(Program.Difficulty.allCases, id: \.self) { diff in
                            filterRow(
                                title: diff.displayName,
                                icon: "speedometer",
                                isSelected: filter.difficulty == diff
                            ) {
                                filter.difficulty = filter.difficulty == diff ? nil : diff
                            }
                        }
                    }
                    .listRowBackground(Constants.Colors.cardBackground)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Filter Programs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        filter = ProgramFilter()
                    }
                    .foregroundColor(Constants.Colors.athleanRed)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Constants.Colors.athleanRed)
                }
            }
        }
    }

    private func filterRow(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? Constants.Colors.athleanRed : Constants.Colors.textSecondary)
                    .frame(width: 20)
                Text(title)
                    .foregroundColor(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Constants.Colors.athleanRed)
                }
            }
        }
    }
}

extension ProgramFilter {
    var isActive: Bool { goal != nil || difficulty != nil || equipment != nil }
}
