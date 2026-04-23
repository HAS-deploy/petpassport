import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Preferences") {
                Picker("Units", selection: $settings.preferredUnits) {
                    ForEach(SettingsStore.MeasurementUnits.allCases) { u in
                        Text(u.label).tag(u)
                    }
                }
            }

            Section("Purchases") {
                HStack {
                    Text("Pro status")
                    Spacer()
                    Text(purchases.isPro ? "Active" : "Not purchased")
                        .foregroundStyle(.secondary)
                }
                Button("Restore purchases") {
                    Task { await purchases.restore() }
                }
            }

            Section("About") {
                Link("Privacy Policy", destination: URL(string: "https://has-deploy.github.io/petpassport/privacy.html")!)
                Link("Terms of Service", destination: URL(string: "https://has-deploy.github.io/petpassport/terms.html")!)
                Link("Support", destination: URL(string: "https://has-deploy.github.io/petpassport/support.html")!)
                LabeledContent("Version", value: appVersion)
            }

            Section {
                Text("Pet Passport is informational only — it summarizes publicly available pet-import requirements. It is not legal or veterinary advice. Always confirm with a USDA-accredited vet and the destination's customs authority before you travel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
