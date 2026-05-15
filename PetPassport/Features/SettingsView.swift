import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var petStore: PetProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var totalScheduled: Int = 0
    @State private var firstTripSummary: String?

    var body: some View {
        Form {
            Section("Preferences") {
                Picker("Units", selection: $settings.preferredUnits) {
                    ForEach(SettingsStore.MeasurementUnits.allCases) { u in
                        Text(u.label).tag(u)
                    }
                }
            }

            Section {
                Toggle("Travel deadline reminders", isOn: $settings.remindersEnabled)
                if settings.remindersEnabled {
                    if totalScheduled > 0, let summary = firstTripSummary {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if totalScheduled > 0 {
                        Text("\(totalScheduled) reminder\(totalScheduled == 1 ? "" : "s") scheduled.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Reminders are scheduled the first time you build a timeline. We'll ask for notification permission then — never before.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Reminders are off. We won't notify you about upcoming microchip, vaccine, titer, or health-cert deadlines.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Reminders")
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
        .task { await refreshScheduledCount() }
        .onChange(of: settings.remindersEnabled) { newValue in
            Task {
                if !newValue {
                    await ReminderScheduler.cancelEverything()
                }
                await refreshScheduledCount()
            }
        }
    }

    private func refreshScheduledCount() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.filter { $0.identifier.hasPrefix("petpassport.reminder.") }
        totalScheduled = ours.count

        // Surface a friendly summary tied to the first pet+destination
        // we can identify from the pending identifiers, e.g.
        // "3 reminders scheduled for Bella's France trip."
        if let firstId = ours.first?.identifier,
           let summary = summaryFor(identifier: firstId, count: ours.count) {
            firstTripSummary = summary
        } else {
            firstTripSummary = nil
        }
    }

    /// Identifier shape:
    /// `petpassport.reminder.<petUUID>.<destinationId>.<itemId>.d<offset>`
    /// We extract pet UUID + destination ID, look the names up, and build a
    /// human-friendly sentence.
    private func summaryFor(identifier: String, count: Int) -> String? {
        let prefix = "petpassport.reminder."
        guard identifier.hasPrefix(prefix) else { return nil }
        let trimmed = String(identifier.dropFirst(prefix.count))
        // Identifier has 4 dot-separated components after the prefix:
        // <petUUID>.<destinationId>.<itemId>.d<offset>. Use maxSplits: 4 so
        // any future `.` inside itemId still keeps the first two components
        // (petUUID and destinationId) intact and parseable.
        let parts = trimmed.split(separator: ".", maxSplits: 4, omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        let petIdString = String(parts[0])
        let destinationId = String(parts[1])
        guard let petUUID = UUID(uuidString: petIdString),
              let pet = petStore.pets.first(where: { $0.id == petUUID }),
              let destination = DestinationCatalog.all.first(where: { $0.id == destinationId })
        else { return nil }
        return "\(count) reminder\(count == 1 ? "" : "s") scheduled for \(pet.name)'s \(destination.name) trip."
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
