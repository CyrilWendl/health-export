import Foundation
import HealthKit

struct HealthSample {
    let date: Date
    let value: Double
}

enum HealthDataType: String, CaseIterable, Identifiable {
    case bodyMass
    case bodyFatPercentage
    case leanBodyMass
    case bodyMassIndex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyMass:
            return "Body Mass"
        case .bodyFatPercentage:
            return "Body Fat Percentage"
        case .leanBodyMass:
            return "Lean Body Mass"
        case .bodyMassIndex:
            return "Body Mass Index"
        }
    }

    var hkIdentifier: HKQuantityTypeIdentifier {
        switch self {
        case .bodyMass:
            return .bodyMass
        case .bodyFatPercentage:
            return .bodyFatPercentage
        case .leanBodyMass:
            return .leanBodyMass
        case .bodyMassIndex:
            return .bodyMassIndex
        }
    }

    var unit: HKUnit {
        switch self {
        case .bodyMass, .leanBodyMass:
            return HKUnit.gramUnit(with: .kilo)
        case .bodyFatPercentage:
            return .percent()
        case .bodyMassIndex:
            return .count()
        }
    }

    var csvHeader: String {
        switch self {
        case .bodyMass, .leanBodyMass:
            return "date,value_kg"
        case .bodyFatPercentage:
            return "date,value_percent"
        case .bodyMassIndex:
            return "date,value_bmi"
        }
    }

    var fileName: String {
        switch self {
        case .bodyMass:
            return "body-mass"
        case .bodyFatPercentage:
            return "body-fat-percentage"
        case .leanBodyMass:
            return "lean-body-mass"
        case .bodyMassIndex:
            return "body-mass-index"
        }
    }
}

enum ExportRange: String, CaseIterable, Identifiable {
    case last30Days
    case last3Months
    case lastYear
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .last30Days:
            return "Last 30 Days"
        case .last3Months:
            return "Last 3 Months"
        case .lastYear:
            return "Last Year"
        case .all:
            return "All"
        }
    }

    func startDate(from referenceDate: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: referenceDate)
        case .last3Months:
            return calendar.date(byAdding: .month, value: -3, to: referenceDate)
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: referenceDate)
        case .all:
            return nil
        }
    }
}

extension Set where Element == HealthDataType {
    static func from(rawValueString: String) -> Set<HealthDataType> {
        let parts = rawValueString.split(separator: ",").map { String($0) }
        let types = parts.compactMap { HealthDataType(rawValue: $0) }
        return Set(types)
    }

    var rawValueString: String {
        let values = map { $0.rawValue }.sorted()
        return values.joined(separator: ",")
    }
}
