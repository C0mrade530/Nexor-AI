import Foundation
import HealthKit
import WatchKit

/// Monitors HealthKit data on Apple Watch and syncs to iPhone companion app.
@MainActor
class WatchHealthMonitor: ObservableObject {
    private let store = HKHealthStore()

    @Published var steps: Int = 0
    @Published var activeCalories: Int = 0
    @Published var activeMinutes: Int = 0
    @Published var heartRate: Int = 0
    @Published var sleepHours: Double = 0
    @Published var energyScore: Int = 0
    @Published var isAuthorized = false

    private var readTypes: Set<HKObjectType> {
        let types: [HKObjectType?] = [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
        ]
        return Set(types.compactMap { $0 })
    }

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await refreshAll()
            return true
        } catch {
            return false
        }
    }

    func refreshAll() async {
        async let s = fetchSteps()
        async let c = fetchActiveCalories()
        async let m = fetchActiveMinutes()
        async let h = fetchHeartRate()
        async let sl = fetchSleepHours()

        steps = await s
        activeCalories = await c
        activeMinutes = await m
        heartRate = await h
        sleepHours = await sl
        energyScore = calculateEnergyScore()
    }

    private func calculateEnergyScore() -> Int {
        var score = 50
        // Sleep factor (7-9h optimal)
        if sleepHours >= 7 && sleepHours <= 9 { score += 25 }
        else if sleepHours >= 6 { score += 15 }
        else if sleepHours >= 5 { score += 5 }

        // Steps factor (10k target)
        let stepScore = min(25, Int(Double(steps) / 10000.0 * 25))
        score += stepScore

        return min(100, max(0, score))
    }

    // MARK: - HealthKit Queries

    private func fetchSteps() async -> Int {
        await fetchSum(for: .stepCount, unit: .count())
    }

    private func fetchActiveCalories() async -> Int {
        await fetchSum(for: .activeEnergyBurned, unit: .kilocalorie())
    }

    private func fetchActiveMinutes() async -> Int {
        await fetchSum(for: .appleExerciseTime, unit: .minute())
    }

    private func fetchHeartRate() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return 0 }
        let now = Date()
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        do {
            let results = try await descriptor.result(for: store)
            if let sample = results.first {
                return Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            }
        } catch {}
        return 0
    }

    private func fetchSleepHours() async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        do {
            let results = try await descriptor.result(for: store)
            var totalSeconds: TimeInterval = 0
            for sample in results {
                let value = sample.value
                // InBed=0, Asleep(Unspecified)=1, Awake=2, Core=3, Deep=4, REM=5
                if value == 1 || value >= 3 {
                    totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                }
            }
            return totalSeconds / 3600.0
        } catch {}
        return 0
    }

    private func fetchSum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: Int(value))
            }
            store.execute(query)
        }
    }
}
