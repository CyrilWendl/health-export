import SwiftUI

struct SettingsView: View {
    @Binding var githubOwner: String
    @Binding var githubRepo: String
    @Binding var githubToken: String
    @Binding var selectedHealthDataTypesRaw: String
    @Binding var exportRangeRaw: String

    @Environment(\.dismiss) private var dismiss
    @State private var isTestingConnection = false
    @State private var connectionMessage: String?

    private var selectedDataTypes: Set<HealthDataType> {
        Set<HealthDataType>.from(rawValueString: selectedHealthDataTypesRaw)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("GitHub Settings") {
                    TextField("Owner", text: $githubOwner)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Repository", text: $githubRepo)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Token", text: $githubToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button(isTestingConnection ? "Testing…" : "Test Connection") {
                        Task { await testGitHubConnection() }
                    }
                    .disabled(isTestingConnection || githubOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || githubRepo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let connectionMessage {
                        Text(connectionMessage)
                            .font(.footnote)
                            .foregroundColor(connectionMessage.hasPrefix("Success") ? .green : .red)
                    }
                }

                Section("Apple Health Data") {
                    ForEach(HealthDataType.allCases) { dataType in
                        Toggle(dataType.displayName, isOn: binding(for: dataType))
                    }
                }

                Section("Export Range") {
                    Picker("Range", selection: $exportRangeRaw) {
                        ForEach(ExportRange.allCases) { range in
                            Text(range.displayName).tag(range.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func binding(for dataType: HealthDataType) -> Binding<Bool> {
        Binding(
            get: {
                selectedDataTypes.contains(dataType)
            },
            set: { isSelected in
                var updated = selectedDataTypes
                if isSelected {
                    updated.insert(dataType)
                } else {
                    updated.remove(dataType)
                }
                selectedHealthDataTypesRaw = updated.rawValueString
            }
        )
    }

    private func testGitHubConnection() async {
        let owner = githubOwner.trimmingCharacters(in: .whitespacesAndNewlines)
        let repo = githubRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = githubToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !owner.isEmpty, !repo.isEmpty else {
            connectionMessage = "Owner and repo are required."
            return
        }

        isTestingConnection = true
        connectionMessage = nil

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)")!
        var request = URLRequest(url: url)
        if !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    connectionMessage = "Success: Repo found."
                } else if httpResponse.statusCode == 404 {
                    connectionMessage = "Failed: Repo not found."
                } else if httpResponse.statusCode == 401 {
                    connectionMessage = "Failed: Unauthorized token."
                } else {
                    connectionMessage = "Failed: HTTP \(httpResponse.statusCode)."
                }
            } else {
                connectionMessage = "Failed: Invalid response."
            }
        } catch {
            connectionMessage = "Failed: \(error.localizedDescription)"
        }

        isTestingConnection = false
    }
}

#Preview {
    SettingsView(
        githubOwner: .constant("CyrilWendl"),
        githubRepo: .constant("muscle-dashboard"),
        githubToken: .constant(""),
        selectedHealthDataTypesRaw: .constant(HealthDataType.bodyMass.rawValue),
        exportRangeRaw: .constant(ExportRange.last30Days.rawValue)
    )
}
