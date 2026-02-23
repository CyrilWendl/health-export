import SwiftUI
import Charts

#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @State private var weight: Double?
    @State private var isExporting = false
    @State private var isExportingAll = false
    @State private var weightHistory: [(date: Date, value: Double)] = []
    @State private var rangeInDays: Int = 30
    @State private var authorizationDenied: Bool = false
    @State private var showSettings = false
    @State private var settingsMessage: String?

    @AppStorage("githubOwner") private var githubOwner: String = ""
    @AppStorage("githubRepo") private var githubRepo: String = ""
    @AppStorage("githubToken") private var githubToken: String = ""
    @AppStorage("selectedHealthDataTypes") private var selectedHealthDataTypesRaw: String = HealthDataType.bodyMass.rawValue
    @AppStorage("exportRange") private var exportRangeRaw: String = ExportRange.last30Days.rawValue

    private let healthManager = HealthManager()

    var selectedDataTypes: Set<HealthDataType> {
        let parsed = Set<HealthDataType>.from(rawValueString: selectedHealthDataTypesRaw)
        return parsed.isEmpty ? [.bodyMass] : parsed
    }

    var exportRange: ExportRange {
        ExportRange(rawValue: exportRangeRaw) ?? .last30Days
    }

    var filteredHistory: [(Date, Double)] {
        let fromDate = Calendar.current.date(byAdding: .day, value: -rangeInDays, to: Date()) ?? .distantPast
        return weightHistory.filter { $0.date >= fromDate }
    }

    var yAxisRange: ClosedRange<Double>? {
        guard let latest = weight else { return nil }
        let weights = filteredHistory.map { $0.1 }
        guard let minWeight = weights.min(), let maxWeight = weights.max() else { return nil }

        let lower = Swift.min(latest - 5, minWeight - 1)
        let upper = Swift.max(latest + 5, maxWeight + 1)
        return lower...upper
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image("Wendl")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .padding(.top, 40)

                VStack(spacing: 12) {
                    Text("Latest Weight")
                        .font(.title2)
                        .foregroundColor(.gray)

                    if !selectedDataTypes.contains(.bodyMass) {
                        Text("Enable Body Mass in Settings")
                            .foregroundColor(.secondary)
                    } else if let weight = weight {
                        Text("\(String(format: "%.1f", weight)) kg")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.primary)
                    } else if authorizationDenied {
                        Text("No permission to read Health data")
                            .foregroundColor(.red)
                    } else {
                        Text("Loading…")
                            .foregroundColor(.gray)
                    }
                }

                Picker("Range", selection: $rangeInDays) {
                    Text("7d").tag(7)
                    Text("30d").tag(30)
                    Text("All").tag(Int.max)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if authorizationDenied {
                    VStack(spacing: 12) {
                        Text("Health permissions are required to show your weight history. Please enable Health permissions in Settings.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        #if canImport(UIKit)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        #endif
                    }
                    Spacer()
                } else {
                    if !filteredHistory.isEmpty {
                        Chart {
                            ForEach(filteredHistory.indices, id: \.self) { idx in
                                let point = filteredHistory[idx]
                                LineMark(
                                    x: .value("Date", point.0),
                                    y: .value("Weight (kg)", point.1)
                                )
                                .interpolationMethod(.monotone)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5))
                        }
                        .chartYScale(domain: yAxisRange ?? 60...100)
                        .frame(height: 220)
                        .padding(.horizontal)
                    } else {
                        Text("No data for selected range")
                    }

                    Spacer()

                    VStack(spacing: 16) {
                        if let settingsMessage {
                            Text(settingsMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        }

                        Button(action: {
                            exportToGitHub()
                        }) {
                            Text(isExporting ? "Exporting…" : "Export Today’s Weight")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CustomButtonStyle())
                        .disabled(isExporting)

                        Button(action: {
                            exportAllToGitHubAsCSV()
                        }) {
                            Text(isExportingAll ? "Exporting All…" : "Export Full History")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CustomButtonStyle())
                        .disabled(isExportingAll)
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal)
            .navigationTitle("Wendl")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    githubOwner: $githubOwner,
                    githubRepo: $githubRepo,
                    githubToken: $githubToken,
                    selectedHealthDataTypesRaw: $selectedHealthDataTypesRaw,
                    exportRangeRaw: $exportRangeRaw
                )
            }
            .onAppear {
                refreshHealthData()
                NotificationManager.shared.requestPermissions()
            }
            .onChange(of: selectedHealthDataTypesRaw) { _ in
                refreshHealthData()
            }
        }
    }

    func todayDateString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private func hasGitHubSettings() -> Bool {
        let trimmedOwner = githubOwner.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRepo = githubRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = githubToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedOwner.isEmpty && !trimmedRepo.isEmpty && !trimmedToken.isEmpty
    }

    private func uploadCSVToGitHub(content: String, filePath: String, message: String, completion: @escaping () -> Void) {
        guard let csvData = content.data(using: .utf8) else {
            completion()
            return
        }

        let base64Content = csvData.base64EncodedString()
        let url = URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/contents/\(filePath)")!

        var getRequest = URLRequest(url: url)
        getRequest.httpMethod = "GET"
        getRequest.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: getRequest) { data, _, _ in
            var existingSHA: String?

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sha = json["sha"] as? String {
                existingSHA = sha
            }

            var putRequest = URLRequest(url: url)
            putRequest.httpMethod = "PUT"
            putRequest.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")
            putRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var body: [String: Any] = [
                "message": message,
                "content": base64Content,
                "committer": [
                    "name": "Health Exporter",
                    "email": "you@example.com"
                ]
            ]
            if let sha = existingSHA {
                body["sha"] = sha
            }

            putRequest.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

            URLSession.shared.dataTask(with: putRequest) { _, response, error in
                if let error = error {
                    print("Upload failed: \(error)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("GitHub upload status: \(httpResponse.statusCode)")
                }
                completion()
            }.resume()
        }.resume()
    }

    func exportToGitHub() {
        settingsMessage = nil
        guard hasGitHubSettings() else {
            settingsMessage = "Please fill in GitHub owner, repo, and token in Settings."
            return
        }
        guard let weight = weight else { return }
        isExporting = true

        let exportData: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: Date()),
            "weight": weight
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            isExporting = false
            return
        }

        let filePath = "Body Metrics/\(todayDateString()).json"
        uploadCSVToGitHub(content: jsonString, filePath: filePath, message: "Update today's weight") {
            DispatchQueue.main.async {
                isExporting = false
            }
        }
    }

    func exportAllToGitHubAsCSV() {
        settingsMessage = nil
        guard hasGitHubSettings() else {
            settingsMessage = "Please fill in GitHub owner, repo, and token in Settings."
            return
        }
        let typesToExport = selectedDataTypes
        guard !typesToExport.isEmpty else {
            settingsMessage = "Please select at least one Health data type in Settings."
            return
        }

        isExportingAll = true
        let group = DispatchGroup()
        let startDate = exportRange.startDate()

        for dataType in typesToExport.sorted(by: { $0.displayName < $1.displayName }) {
            group.enter()
            healthManager.fetchQuantityHistory(for: dataType, startDate: startDate) { samples in
                guard !samples.isEmpty else {
                    group.leave()
                    return
                }

                var csvString = "\(dataType.csvHeader)\n"
                let formatter = ISO8601DateFormatter()

                for sample in samples {
                    let date = formatter.string(from: sample.date)
                    csvString += "\(date),\(String(format: "%.4f", sample.value))\n"
                }

                let filePath = "Health Data/\(dataType.fileName)-\(exportRange.rawValue).csv"
                uploadCSVToGitHub(content: csvString, filePath: filePath, message: "Upload \(dataType.displayName) history") {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            isExportingAll = false
        }
    }

    private func refreshHealthData() {
        settingsMessage = nil
        let dataTypes = selectedDataTypes
        healthManager.requestAuthorization(for: dataTypes) { success in
            if success {
                authorizationDenied = false
                if dataTypes.contains(.bodyMass) {
                    healthManager.fetchMostRecentSample(for: .bodyMass) { value in
                        DispatchQueue.main.async {
                            self.weight = value
                        }
                    }

                    healthManager.fetchQuantityHistory(for: .bodyMass, startDate: nil) { samples in
                        let parsed = samples.map { (date: $0.date, value: $0.value) }
                        DispatchQueue.main.async {
                            self.weightHistory = parsed
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.weight = nil
                        self.weightHistory = []
                    }
                }
            } else {
                authorizationDenied = true
            }
        }
    }
}

#Preview{
    ContentView()
}
