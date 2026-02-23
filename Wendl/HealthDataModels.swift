import Foundation
import HealthKit

enum HealthDataKind {
    case quantity
    case category
}

struct HealthSample {
    let startDate: Date
    let endDate: Date
    let value: Double
}

enum HealthDataCategory: String, CaseIterable, Identifiable {
    case bodyMeasurements
    case heart
    case activity
    case energy
    case nutrition
    case vitals
    case mobility
    case environment
    case respiratory
    case mindfulnessSleep
    case reproductive
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyMeasurements:
            return "Body Measurements"
        case .heart:
            return "Heart"
        case .activity:
            return "Activity"
        case .energy:
            return "Energy"
        case .nutrition:
            return "Nutrition"
        case .vitals:
            return "Vitals"
        case .mobility:
            return "Mobility"
        case .environment:
            return "Environment"
        case .respiratory:
            return "Respiratory"
        case .mindfulnessSleep:
            return "Mindfulness & Sleep"
        case .reproductive:
            return "Reproductive Health"
        case .other:
            return "Other"
        }
    }
}

struct HealthDataType: Identifiable, Hashable {
    let id: String
    let displayName: String
    let kind: HealthDataKind
    let category: HealthDataCategory
    let quantityIdentifier: HKQuantityTypeIdentifier?
    let categoryIdentifier: HKCategoryTypeIdentifier?
    let unit: HKUnit?
    let fileName: String

    var csvHeader: String {
        switch kind {
        case .quantity:
            return "date,value"
        case .category:
            return "start_date,end_date,value"
        }
    }

    var sampleType: HKSampleType? {
        switch kind {
        case .quantity:
            guard let identifier = quantityIdentifier else { return nil }
            return HKObjectType.quantityType(forIdentifier: identifier)
        case .category:
            guard let identifier = categoryIdentifier else { return nil }
            return HKObjectType.categoryType(forIdentifier: identifier)
        }
    }

    static var bodyMass: HealthDataType {
        lookup(by: "quantity.\(HKQuantityTypeIdentifier.bodyMass.rawValue)")
            ?? HealthDataType(
                id: "quantity.\(HKQuantityTypeIdentifier.bodyMass.rawValue)",
                displayName: "Body Weight",
                kind: .quantity,
                category: .bodyMeasurements,
                quantityIdentifier: .bodyMass,
                categoryIdentifier: nil,
                unit: .gramUnit(with: .kilo),
                fileName: "body-weight"
            )
    }

    static var all: [HealthDataType] {
        var items: [HealthDataType] = []

        func addQuantity(_ identifier: HKQuantityTypeIdentifier, _ displayName: String, unit: HKUnit, fileName: String, category: HealthDataCategory) {
            let id = "quantity.\(identifier.rawValue)"
            items.append(HealthDataType(
                id: id,
                displayName: displayName,
                kind: .quantity,
                category: category,
                quantityIdentifier: identifier,
                categoryIdentifier: nil,
                unit: unit,
                fileName: fileName
            ))
        }

        func addCategory(_ identifier: HKCategoryTypeIdentifier, _ displayName: String, fileName: String, category: HealthDataCategory) {
            let id = "category.\(identifier.rawValue)"
            items.append(HealthDataType(
                id: id,
                displayName: displayName,
                kind: .category,
                category: category,
                quantityIdentifier: nil,
                categoryIdentifier: identifier,
                unit: nil,
                fileName: fileName
            ))
        }

        addQuantity(.bodyMass, "Body Weight", unit: .gramUnit(with: .kilo), fileName: "body-weight", category: .bodyMeasurements)
        addQuantity(.bodyFatPercentage, "Body Fat Percentage", unit: .percent(), fileName: "body-fat-percentage", category: .bodyMeasurements)
        addQuantity(.leanBodyMass, "Lean Body Mass", unit: .gramUnit(with: .kilo), fileName: "lean-body-mass", category: .bodyMeasurements)
        addQuantity(.bodyMassIndex, "Body Mass Index", unit: .count(), fileName: "body-mass-index", category: .bodyMeasurements)
        addQuantity(.height, "Height", unit: .meter(), fileName: "height", category: .bodyMeasurements)
        addQuantity(.waistCircumference, "Waist Circumference", unit: .meter(), fileName: "waist-circumference", category: .bodyMeasurements)

        addQuantity(.heartRate, "Heart Rate", unit: HKUnit.count().unitDivided(by: .minute()), fileName: "heart-rate", category: .heart)
        addQuantity(.restingHeartRate, "Resting Heart Rate", unit: HKUnit.count().unitDivided(by: .minute()), fileName: "resting-heart-rate", category: .heart)
        addQuantity(.walkingHeartRateAverage, "Walking Heart Rate Average", unit: HKUnit.count().unitDivided(by: .minute()), fileName: "walking-heart-rate-average", category: .heart)
        addQuantity(.heartRateVariabilitySDNN, "HRV (SDNN)", unit: .secondUnit(with: .milli), fileName: "heart-rate-variability-sdnn", category: .heart)

        addQuantity(.stepCount, "Step Count", unit: .count(), fileName: "step-count", category: .activity)
        addQuantity(.distanceWalkingRunning, "Distance Walking/Running", unit: .meter(), fileName: "distance-walking-running", category: .activity)
        addQuantity(.distanceCycling, "Distance Cycling", unit: .meter(), fileName: "distance-cycling", category: .activity)
        addQuantity(.distanceWheelchair, "Distance Wheelchair", unit: .meter(), fileName: "distance-wheelchair", category: .activity)
        addQuantity(.flightsClimbed, "Flights Climbed", unit: .count(), fileName: "flights-climbed", category: .activity)

        addQuantity(.basalEnergyBurned, "Basal Energy Burned", unit: .kilocalorie(), fileName: "basal-energy-burned", category: .energy)
        addQuantity(.activeEnergyBurned, "Active Energy Burned", unit: .kilocalorie(), fileName: "active-energy-burned", category: .energy)
        addQuantity(.dietaryEnergyConsumed, "Dietary Energy", unit: .kilocalorie(), fileName: "dietary-energy", category: .nutrition)

        addQuantity(.dietaryCarbohydrates, "Dietary Carbohydrates", unit: .gram(), fileName: "dietary-carbohydrates", category: .nutrition)
        addQuantity(.dietaryProtein, "Dietary Protein", unit: .gram(), fileName: "dietary-protein", category: .nutrition)
        addQuantity(.dietaryFatTotal, "Dietary Fat", unit: .gram(), fileName: "dietary-fat-total", category: .nutrition)
        addQuantity(.dietaryWater, "Dietary Water", unit: .liter(), fileName: "dietary-water", category: .nutrition)
        addQuantity(.dietarySugar, "Dietary Sugar", unit: .gram(), fileName: "dietary-sugar", category: .nutrition)
        addQuantity(.dietaryFiber, "Dietary Fiber", unit: .gram(), fileName: "dietary-fiber", category: .nutrition)
        addQuantity(.dietaryCaffeine, "Dietary Caffeine", unit: .gramUnit(with: .milli), fileName: "dietary-caffeine", category: .nutrition)
        addQuantity(.dietaryCholesterol, "Dietary Cholesterol", unit: .gramUnit(with: .milli), fileName: "dietary-cholesterol", category: .nutrition)
        addQuantity(.dietarySodium, "Dietary Sodium", unit: .gramUnit(with: .milli), fileName: "dietary-sodium", category: .nutrition)
        addQuantity(.dietaryPotassium, "Dietary Potassium", unit: .gramUnit(with: .milli), fileName: "dietary-potassium", category: .nutrition)
        addQuantity(.dietaryCalcium, "Dietary Calcium", unit: .gramUnit(with: .milli), fileName: "dietary-calcium", category: .nutrition)
        addQuantity(.dietaryIron, "Dietary Iron", unit: .gramUnit(with: .milli), fileName: "dietary-iron", category: .nutrition)
        addQuantity(.dietaryVitaminA, "Dietary Vitamin A", unit: .gramUnit(with: .micro), fileName: "dietary-vitamin-a", category: .nutrition)
        addQuantity(.dietaryVitaminC, "Dietary Vitamin C", unit: .gramUnit(with: .milli), fileName: "dietary-vitamin-c", category: .nutrition)
        addQuantity(.dietaryVitaminD, "Dietary Vitamin D", unit: .gramUnit(with: .micro), fileName: "dietary-vitamin-d", category: .nutrition)
        addQuantity(.dietaryVitaminE, "Dietary Vitamin E", unit: .gramUnit(with: .milli), fileName: "dietary-vitamin-e", category: .nutrition)
        addQuantity(.dietaryVitaminB6, "Dietary Vitamin B6", unit: .gramUnit(with: .milli), fileName: "dietary-vitamin-b6", category: .nutrition)
        addQuantity(.dietaryVitaminB12, "Dietary Vitamin B12", unit: .gramUnit(with: .micro), fileName: "dietary-vitamin-b12", category: .nutrition)
        addQuantity(.dietaryFolate, "Dietary Folate", unit: .gramUnit(with: .micro), fileName: "dietary-folate", category: .nutrition)
        addQuantity(.dietaryThiamin, "Dietary Thiamin", unit: .gramUnit(with: .milli), fileName: "dietary-thiamin", category: .nutrition)
        addQuantity(.dietaryRiboflavin, "Dietary Riboflavin", unit: .gramUnit(with: .milli), fileName: "dietary-riboflavin", category: .nutrition)
        addQuantity(.dietaryNiacin, "Dietary Niacin", unit: .gramUnit(with: .milli), fileName: "dietary-niacin", category: .nutrition)
        addQuantity(.dietaryBiotin, "Dietary Biotin", unit: .gramUnit(with: .micro), fileName: "dietary-biotin", category: .nutrition)
        addQuantity(.dietaryPantothenicAcid, "Dietary Pantothenic Acid", unit: .gramUnit(with: .milli), fileName: "dietary-pantothenic-acid", category: .nutrition)
        addQuantity(.dietaryPhosphorus, "Dietary Phosphorus", unit: .gramUnit(with: .milli), fileName: "dietary-phosphorus", category: .nutrition)
        addQuantity(.dietaryMagnesium, "Dietary Magnesium", unit: .gramUnit(with: .milli), fileName: "dietary-magnesium", category: .nutrition)
        addQuantity(.dietaryCopper, "Dietary Copper", unit: .gramUnit(with: .micro), fileName: "dietary-copper", category: .nutrition)
        addQuantity(.dietaryZinc, "Dietary Zinc", unit: .gramUnit(with: .milli), fileName: "dietary-zinc", category: .nutrition)
        addQuantity(.dietarySelenium, "Dietary Selenium", unit: .gramUnit(with: .micro), fileName: "dietary-selenium", category: .nutrition)
        addQuantity(.dietaryManganese, "Dietary Manganese", unit: .gramUnit(with: .milli), fileName: "dietary-manganese", category: .nutrition)
        addQuantity(.dietaryChromium, "Dietary Chromium", unit: .gramUnit(with: .micro), fileName: "dietary-chromium", category: .nutrition)
        addQuantity(.dietaryMolybdenum, "Dietary Molybdenum", unit: .gramUnit(with: .micro), fileName: "dietary-molybdenum", category: .nutrition)
        addQuantity(.dietaryChloride, "Dietary Chloride", unit: .gramUnit(with: .milli), fileName: "dietary-chloride", category: .nutrition)
        addQuantity(.dietaryIodine, "Dietary Iodine", unit: .gramUnit(with: .micro), fileName: "dietary-iodine", category: .nutrition)

        addQuantity(.bloodPressureSystolic, "Blood Pressure Systolic", unit: .millimeterOfMercury(), fileName: "blood-pressure-systolic", category: .vitals)
        addQuantity(.bloodPressureDiastolic, "Blood Pressure Diastolic", unit: .millimeterOfMercury(), fileName: "blood-pressure-diastolic", category: .vitals)
        addQuantity(.bloodGlucose, "Blood Glucose", unit: HKUnit(from: "mg/dL"), fileName: "blood-glucose", category: .vitals)
        addQuantity(.oxygenSaturation, "Oxygen Saturation", unit: .percent(), fileName: "oxygen-saturation", category: .vitals)
        addQuantity(.respiratoryRate, "Respiratory Rate", unit: HKUnit.count().unitDivided(by: .minute()), fileName: "respiratory-rate", category: .vitals)
        addQuantity(.bodyTemperature, "Body Temperature", unit: .degreeCelsius(), fileName: "body-temperature", category: .vitals)
        addQuantity(.electrodermalActivity, "Electrodermal Activity", unit: .siemen(), fileName: "electrodermal-activity", category: .vitals)
        addQuantity(.peripheralPerfusionIndex, "Peripheral Perfusion Index", unit: .percent(), fileName: "peripheral-perfusion-index", category: .vitals)

        addQuantity(.vo2Max, "VO2 Max", unit: HKUnit(from: "ml/(kg*min)"), fileName: "vo2-max", category: .mobility)
        addQuantity(.walkingSpeed, "Walking Speed", unit: HKUnit.meter().unitDivided(by: .second()), fileName: "walking-speed", category: .mobility)
        addQuantity(.walkingStepLength, "Walking Step Length", unit: .meter(), fileName: "walking-step-length", category: .mobility)
        addQuantity(.sixMinuteWalkTestDistance, "Six-Minute Walk Distance", unit: .meter(), fileName: "six-minute-walk-distance", category: .mobility)
        addQuantity(.stairAscentSpeed, "Stair Ascent Speed", unit: HKUnit.meter().unitDivided(by: .second()), fileName: "stair-ascent-speed", category: .mobility)
        addQuantity(.stairDescentSpeed, "Stair Descent Speed", unit: HKUnit.meter().unitDivided(by: .second()), fileName: "stair-descent-speed", category: .mobility)
        addQuantity(.walkingAsymmetryPercentage, "Walking Asymmetry", unit: .percent(), fileName: "walking-asymmetry", category: .mobility)
        addQuantity(.walkingDoubleSupportPercentage, "Walking Double Support", unit: .percent(), fileName: "walking-double-support", category: .mobility)

        if #available(iOS 16.0, *) {
            addQuantity(.runningSpeed, "Running Speed", unit: HKUnit.meter().unitDivided(by: .second()), fileName: "running-speed", category: .mobility)
            addQuantity(.runningStrideLength, "Running Stride Length", unit: .meter(), fileName: "running-stride-length", category: .mobility)
            addQuantity(.runningPower, "Running Power", unit: .watt(), fileName: "running-power", category: .mobility)
            addQuantity(.runningVerticalOscillation, "Running Vertical Oscillation", unit: .meter(), fileName: "running-vertical-oscillation", category: .mobility)
            addQuantity(.runningGroundContactTime, "Running Ground Contact Time", unit: .secondUnit(with: .milli), fileName: "running-ground-contact-time", category: .mobility)
        }

        addQuantity(.environmentalAudioExposure, "Environmental Audio Exposure", unit: .decibelAWeightedSoundPressureLevel(), fileName: "environmental-audio-exposure", category: .environment)
        addQuantity(.headphoneAudioExposure, "Headphone Audio Exposure", unit: .decibelAWeightedSoundPressureLevel(), fileName: "headphone-audio-exposure", category: .environment)
        addQuantity(.uvExposure, "UV Exposure", unit: .count(), fileName: "uv-exposure", category: .environment)

        addQuantity(.appleExerciseTime, "Apple Exercise Time", unit: .minute(), fileName: "apple-exercise-time", category: .activity)
        addQuantity(.appleStandTime, "Apple Stand Time", unit: .minute(), fileName: "apple-stand-time", category: .activity)

        addQuantity(.bloodAlcoholContent, "Blood Alcohol Content", unit: .percent(), fileName: "blood-alcohol-content", category: .other)
        addQuantity(.insulinDelivery, "Insulin Delivery", unit: .internationalUnit(), fileName: "insulin-delivery", category: .other)
        addQuantity(.inhalerUsage, "Inhaler Usage", unit: .count(), fileName: "inhaler-usage", category: .respiratory)
        addQuantity(.numberOfTimesFallen, "Number of Times Fallen", unit: .count(), fileName: "number-of-times-fallen", category: .other)
        addQuantity(.peakExpiratoryFlowRate, "Peak Expiratory Flow Rate", unit: HKUnit(from: "L/min"), fileName: "peak-expiratory-flow-rate", category: .respiratory)
        addQuantity(.forcedVitalCapacity, "Forced Vital Capacity", unit: .liter(), fileName: "forced-vital-capacity", category: .respiratory)
        addQuantity(.forcedExpiratoryVolume1, "Forced Expiratory Volume (1s)", unit: .liter(), fileName: "forced-expiratory-volume-1s", category: .respiratory)

        addCategory(.sleepAnalysis, "Sleep Analysis", fileName: "sleep-analysis", category: .mindfulnessSleep)
        addCategory(.mindfulSession, "Mindful Session", fileName: "mindful-session", category: .mindfulnessSleep)
        addCategory(.appleStandHour, "Apple Stand Hour", fileName: "apple-stand-hour", category: .activity)
        addCategory(.highHeartRateEvent, "High Heart Rate Event", fileName: "high-heart-rate-event", category: .heart)
        addCategory(.lowHeartRateEvent, "Low Heart Rate Event", fileName: "low-heart-rate-event", category: .heart)
        addCategory(.irregularHeartRhythmEvent, "Irregular Heart Rhythm", fileName: "irregular-heart-rhythm-event", category: .heart)
        addCategory(.menstrualFlow, "Menstrual Flow", fileName: "menstrual-flow", category: .reproductive)
        addCategory(.intermenstrualBleeding, "Intermenstrual Bleeding", fileName: "intermenstrual-bleeding", category: .reproductive)
        addCategory(.sexualActivity, "Sexual Activity", fileName: "sexual-activity", category: .reproductive)
        addCategory(.ovulationTestResult, "Ovulation Test Result", fileName: "ovulation-test-result", category: .reproductive)
        addCategory(.cervicalMucusQuality, "Cervical Mucus Quality", fileName: "cervical-mucus-quality", category: .reproductive)
        addCategory(.contraceptive, "Contraceptive", fileName: "contraceptive", category: .reproductive)
        addCategory(.toothbrushingEvent, "Toothbrushing", fileName: "toothbrushing", category: .other)
        addCategory(.handwashingEvent, "Handwashing", fileName: "handwashing", category: .other)

        return items
    }

    static var groupedByCategory: [(HealthDataCategory, [HealthDataType])] {
        HealthDataCategory.allCases.compactMap { category in
            let items = all
                .filter { $0.category == category }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            return items.isEmpty ? nil : (category, items)
        }
    }

    static func lookup(by id: String) -> HealthDataType? {
        all.first { $0.id == id }
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
        let types = parts.compactMap { HealthDataType.lookup(by: $0) }
        return Set(types)
    }

    var rawValueString: String {
        let values = map { $0.id }.sorted()
        return values.joined(separator: ",")
    }
}
