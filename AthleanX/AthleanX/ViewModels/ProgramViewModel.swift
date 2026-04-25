import Foundation
import Combine

@MainActor
final class ProgramViewModel: ObservableObject {
    @Published var programs: [Program] = []
    @Published var featuredPrograms: [Program] = []
    @Published var selectedProgram: Program?
    @Published var filter = ProgramFilter()
    @Published var isLoading = false
    @Published var isEnrolling = false
    @Published var errorMessage: String?
    @Published var enrollSuccessMessage: String?

    var filteredPrograms: [Program] {
        programs.filter { program in
            if let goal = filter.goal, !program.goals.contains(goal) { return false }
            if let diff = filter.difficulty, program.difficulty != diff { return false }
            return true
        }
    }

    func loadPrograms() async {
        isLoading = true
        errorMessage = nil
        do {
            programs = try await WorkoutService.shared.fetchPrograms()
            featuredPrograms = Array(programs.prefix(3))
        } catch {
            errorMessage = "Failed to load programs."
        }
        isLoading = false
    }

    func loadProgram(id: Int) async {
        isLoading = true
        do {
            selectedProgram = try await WorkoutService.shared.fetchProgram(id: id)
        } catch {
            errorMessage = "Failed to load program details."
        }
        isLoading = false
    }

    func enrollInProgram(_ program: Program) async {
        isEnrolling = true
        errorMessage = nil
        do {
            let enrolled = try await WorkoutService.shared.enrollInProgram(id: program.id)
            selectedProgram = enrolled
            enrollSuccessMessage = "You're now enrolled in \(program.name)! Let's get after it."
        } catch {
            errorMessage = "Failed to enroll. Please try again."
        }
        isEnrolling = false
    }

    func clearFilter() {
        filter = ProgramFilter()
    }
}
