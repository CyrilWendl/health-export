import SwiftUI
import Charts

struct ContentView: View {
    @State private var weight: Double?
    @State private var isExporting = false
    @State private var isExportingAll = false
    @State private var weightHistory: [(date: Date, value: Double)] = []
    @State private var rangeInDays: Int = 30

    private let healthManager = HealthManager()

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

                if let weight = weight {
                    Text("\(String(format: "%.1f", weight)) kg")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.primary)
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

            if !filteredHistory.isEmpty {
                Chart {
                    ForEach(filteredHistory, id: \ .0) { point in
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
        .padding(.horizontal)
        .onAppear {
            healthManager.requestAuthorization { success in
                if success {
                    healthManager.fetchMostRecentWeight { value in
                        DispatchQueue.main.async {
                            self.weight = value
                        }
                    }

                    healthManager.fetchWeightHistory { data in
                        let parsed = data.compactMap { entry -> (Date, Double)? in
                            guard let dateString = entry["date"] as? String,
                                  let weight = entry["weight"] as? Double,
                                  let date = ISO8601DateFormatter().date(from: dateString) else {
                                return nil
                            }
                            return (date, weight)
                        }
                        DispatchQueue.main.async {
                            self.weightHistory = parsed
                        }
                    }
                }
            }
            NotificationManager.shared.requestPermissions()
        }
    }

    func todayDateString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }


    func exportToGitHub() {
        guard let weight = weight else { return }
        isExporting = true

        let exportData: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: Date()),
            "weight": weight
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted) else {
            isExporting = false
            return
        }

        let base64Content = jsonData.base64EncodedString()
        let githubToken = "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"  // 🔐 Replace with your token
        let owner = "CyrilWendl"               // 🔁 Replace with your GitHub username
        let repo = "muscle-dashboard"             // 🔁 Replace with your repo
        let filePath = "Body Metrics/\(todayDateString()).json"
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(filePath)")!

        var getRequest = URLRequest(url: url)
        getRequest.httpMethod = "GET"
        getRequest.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: getRequest) { data, _, _ in
            var existingSHA: String? = nil

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
                "message": "Update today's weight",
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
                DispatchQueue.main.async {
                    isExporting = false
                }

                if let error = error {
                    print("Upload failed: \(error)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("GitHub upload status: \(httpResponse.statusCode)")
                }
            }.resume()

        }.resume()
    }

    func exportAllToGitHubAsCSV() {
        isExportingAll = true

        healthManager.fetchWeightHistory { data in
            guard !data.isEmpty else {
                isExportingAll = false
                return
            }

            var csvString = "date,weight_kg\n"

            for entry in data {
                if let date = entry["date"] as? String,
                   let weight = entry["weight"] as? Double {
                    csvString += "\(date),\(String(format: "%.2f", weight))\n"
                }
            }

            guard let csvData = csvString.data(using: .utf8) else {
                isExportingAll = false
                return
            }

            let base64Content = csvData.base64EncodedString()
            let githubToken = "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"  // 🔐 Replace with your token
            let owner = "CyrilWendl"               // 🔁 Replace with your GitHub username
            let repo = "muscle-dashboard"             // 🔁 Replace with your repo
            let filePath = "Body Metrics/weight-history.csv"
            let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(filePath)")!

            var getRequest = URLRequest(url: url)
            getRequest.httpMethod = "GET"
            getRequest.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: getRequest) { data, _, _ in
                var existingSHA: String? = nil

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
                    "message": "Upload full weight history as CSV",
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

                URLSession.shared.dataTask(with: putRequest) { data, response, error in
                    DispatchQueue.main.async {
                        isExportingAll = false
                    }

                    if let error = error {
                        print("Upload failed: \(error)")
                    } else if let httpResponse = response as? HTTPURLResponse {
                        print("GitHub upload status: \(httpResponse.statusCode)")

                        if let data = data,
                           let responseBody = String(data: data, encoding: .utf8) {
                            print("GitHub response body: \(responseBody)")
                        }
                    }
                }.resume()
            }.resume()
        }
    }
}
