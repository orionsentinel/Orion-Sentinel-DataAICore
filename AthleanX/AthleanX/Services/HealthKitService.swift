import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.stepCount),
        ]
    }

    private var writeTypes: Set<HKSampleType> {
        [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKWorkoutType.workoutType(),
        ]
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    // MARK: - Today stats

    func todayActiveCalories() async -> Double {
        await sumToday(type: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie())
    }

    func todayRestingCalories() async -> Double {
        await sumToday(type: HKQuantityType(.basalEnergyBurned), unit: .kilocalorie())
    }

    func todaySteps() async -> Double {
        await sumToday(type: HKQuantityType(.stepCount), unit: .count())
    }

    private func sumToday(type: HKQuantityType, unit: HKUnit) async -> Double {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: Calendar.current.startOfDay(for: Date()),
                end: Date()
            )
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    // MARK: - Latest samples

    func latestWeight() async -> (value: Double, date: Date)? {
        guard let sample = await latestSample(type: HKQuantityType(.bodyMass)) as? HKQuantitySample
        else { return nil }
        return (sample.quantity.doubleValue(for: .pound()), sample.endDate)
    }

    func latestBodyFat() async -> Double? {
        guard let sample = await latestSample(type: HKQuantityType(.bodyFatPercentage)) as? HKQuantitySample
        else { return nil }
        // HealthKit stores as ratio 0.0–1.0; multiply by 100 for display
        return sample.quantity.doubleValue(for: HKUnit(from: "%")) * 100
    }

    private func latestSample(type: HKQuantityType) async -> HKSample? {
        await withCheckedContinuation { continuation in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: sort
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first)
            }
            store.execute(query)
        }
    }

    // MARK: - Write workout

    func saveWorkout(start: Date, duration: Int, estimatedCalories: Double) async throws {
        guard isAvailable else { return }
        let end = start.addingTimeInterval(TimeInterval(duration))

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: start)

        let energySample = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories),
            start: start,
            end: end
        )
        try await builder.addSamples([energySample])
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }

    // MARK: - Write body metrics

    func saveWeight(_ lbs: Double, date: Date) async throws {
        guard isAvailable else { return }
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: .pound(), doubleValue: lbs),
            start: date,
            end: date
        )
        try await store.save(sample)
    }

    func saveBodyFat(_ percentage: Double, date: Date) async throws {
        guard isAvailable else { return }
        // HealthKit stores body fat as ratio 0.0–1.0
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyFatPercentage),
            quantity: HKQuantity(unit: HKUnit(from: "%"), doubleValue: percentage / 100),
            start: date,
            end: date
        )
        try await store.save(sample)
    }
}
