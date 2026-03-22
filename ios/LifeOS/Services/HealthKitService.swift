import Foundation
import HealthKit

/// HealthKit integration — reads sleep, steps, workouts, heart data from Apple Watch / iPhone.
@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    @Published var isAuthorized = false
    @Published var todaySnapshot: HealthSnapshot?

    struct HealthSnapshot {
        var sleepHours: Double?
        var sleepQuality: Int?
        var steps: Int?
        var activeCalories: Int?
        var activeMinutes: Int?
        var restingHR: Int?
        var hrv: Int?
        var workouts: [WorkoutSummary] = []
    }

    struct WorkoutSummary {
        let type: String
        let durationMinutes: Int
        let calories: Int
        let distance: Double?
    }

    // Types we want to read
    private var readTypes: Set<HKObjectType> {
        let types: [HKObjectType?] = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.workoutType(),
        ]
        return Set(types.compactMap { $0 })
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    /// Fetch today's health data and sync to backend.
    func syncToday() async -> HealthSnapshot? {
        guard isAvailable else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        var snapshot = HealthSnapshot()

        // Steps
        if let steps = await fetchSum(.stepCount, unit: .count(), start: startOfDay, end: now) {
            snapshot.steps = Int(steps)
        }

        // Active calories
        if let cals = await fetchSum(.activeEnergyBurned, unit: .kilocalorie(), start: startOfDay, end: now) {
            snapshot.activeCalories = Int(cals)
        }

        // Exercise minutes
        if let mins = await fetchSum(.appleExerciseTime, unit: .minute(), start: startOfDay, end: now) {
            snapshot.activeMinutes = Int(mins)
        }

        // Resting heart rate (latest)
        if let rhr = await fetchLatest(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute())) {
            snapshot.restingHR = Int(rhr)
        }

        // HRV
        if let hrv = await fetchLatest(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) {
            snapshot.hrv = Int(hrv)
        }

        // Sleep (last night)
        let sleepStart = calendar.date(byAdding: .hour, value: -24, to: now)!
        snapshot.sleepHours = await fetchSleepHours(start: sleepStart, end: now)

        // Workouts today
        snapshot.workouts = await fetchWorkouts(start: startOfDay, end: now)

        self.todaySnapshot = snapshot

        // Sync to backend
        await syncToBackend(snapshot)

        return snapshot
    }

    // MARK: - HealthKit Queries

    private func fetchSum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchLatest(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchSleepHours(start: Date, end: Date) async -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Sum asleep time (InBed, Asleep, Deep, Core, REM)
                var totalSeconds: TimeInterval = 0
                for sample in samples {
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    if value != .inBed {
                        totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }

                let hours = totalSeconds / 3600.0
                continuation.resume(returning: hours > 0 ? round(hours * 10) / 10 : nil)
            }
            store.execute(query)
        }
    }

    private func fetchWorkouts(start: Date, end: Date) async -> [WorkoutSummary] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 10,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let summaries = workouts.map { workout in
                    WorkoutSummary(
                        type: workout.workoutActivityType.displayName,
                        durationMinutes: Int(workout.duration / 60),
                        calories: Int(workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0),
                        distance: workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo))
                    )
                }
                continuation.resume(returning: summaries)
            }
            store.execute(query)
        }
    }

    // MARK: - Backend Sync

    private func syncToBackend(_ snapshot: HealthSnapshot) async {
        let today = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        var body: [String: Any] = ["date": today]

        if let sleep = snapshot.sleepHours {
            body["sleep"] = ["total_hours": sleep, "quality_score": snapshot.sleepQuality as Any]
        }

        var activity: [String: Any] = [:]
        if let steps = snapshot.steps { activity["steps"] = steps }
        if let cals = snapshot.activeCalories { activity["active_calories"] = cals }
        if let mins = snapshot.activeMinutes { activity["active_minutes"] = mins }
        if !activity.isEmpty { body["activity"] = activity }

        var heart: [String: Any] = [:]
        if let rhr = snapshot.restingHR { heart["resting_hr"] = rhr }
        if let hrv = snapshot.hrv { heart["hrv"] = hrv }
        if !heart.isEmpty { body["heart"] = heart }

        if !snapshot.workouts.isEmpty {
            body["workouts"] = snapshot.workouts.map { w in
                [
                    "type": w.type,
                    "duration_minutes": w.durationMinutes,
                    "calories": w.calories,
                ] as [String: Any]
            }
        }

        do {
            let _: EmptyResponse = try await APIClient.shared.post("/health/sync", body: body)
        } catch {
            print("Health sync failed: \(error)")
        }
    }
}

// MARK: - Workout Type Names

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "running"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .walking: return "walking"
        case .yoga: return "yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "strength"
        case .highIntensityIntervalTraining: return "hiit"
        case .dance: return "dance"
        case .boxing, .kickboxing: return "boxing"
        case .rowing: return "rowing"
        case .elliptical: return "elliptical"
        case .pilates: return "pilates"
        default: return "other"
        }
    }
}
