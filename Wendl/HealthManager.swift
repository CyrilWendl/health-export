import Foundation
import HealthKit

class HealthManager {
    let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        let readTypes: Set = [
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        ]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let error = error {
                print("Authorization failed: \(error.localizedDescription)")
            }
            // Ensure completion is always called on main thread so callers can update UI safely
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    func fetchMostRecentWeight(completion: @escaping (Double?) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightType,
                                  predicate: nil,
                                  limit: 1,
                                  sortDescriptors: [sortDescriptor]) { _, results, _ in
            if let result = results?.first as? HKQuantitySample {
                let weightInKg = result.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                completion(weightInKg)
            } else {
                completion(nil)
            }
        }

        healthStore.execute(query)
    }

    func fetchWeightHistory(completion: @escaping ([[String: Any]]) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion([])
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let predicate = HKQuery.predicateForSamples(withStart: .distantPast, end: Date(), options: [])

        let query = HKSampleQuery(sampleType: weightType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sortDescriptor]) { _, results, _ in
            var exportData: [[String: Any]] = []

            for case let sample as HKQuantitySample in results ?? [] {
                let weight = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                let date = ISO8601DateFormatter().string(from: sample.startDate)

                exportData.append([
                    "date": date,
                    "weight": weight
                ])
            }

            completion(exportData)
        }

        healthStore.execute(query)
    }
}
