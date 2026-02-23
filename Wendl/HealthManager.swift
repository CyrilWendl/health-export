import Foundation
import HealthKit

class HealthManager {
    let healthStore = HKHealthStore()

    // Request authorization for the specified health data types
    func requestAuthorization(for dataTypes: Set<HealthDataType>, completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        let readTypes: Set<HKObjectType> = Set(dataTypes.compactMap {
            HKObjectType.quantityType(forIdentifier: $0.hkIdentifier)
        })

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let error = error {
                print("Authorization failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    // Fetch the most recent sample for the specified data type
    func fetchMostRecentSample(for dataType: HealthDataType, completion: @escaping (Double?) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: dataType.hkIdentifier) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: quantityType,
                                  predicate: nil,
                                  limit: 1,
                                  sortDescriptors: [sortDescriptor]) { _, results, _ in
            if let result = results?.first as? HKQuantitySample {
                let value = result.quantity.doubleValue(for: dataType.unit)
                completion(value)
            } else {
                completion(nil)
            }
        }

        healthStore.execute(query)
    }

    // Fetch the history of quantity samples for the specified data type and date range
    func fetchQuantityHistory(for dataType: HealthDataType,
                              startDate: Date?,
                              endDate: Date = Date(),
                              completion: @escaping ([HealthSample]) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: dataType.hkIdentifier) else {
            completion([])
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let predicate = HKQuery.predicateForSamples(withStart: startDate ?? .distantPast, end: endDate, options: [])

        let query = HKSampleQuery(sampleType: quantityType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sortDescriptor]) { _, results, _ in
            let samples: [HealthSample] = (results ?? []).compactMap { sample in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                let value = quantitySample.quantity.doubleValue(for: dataType.unit)
                return HealthSample(date: quantitySample.startDate, value: value)
            }

            completion(samples)
        }

        healthStore.execute(query)
    }
}
