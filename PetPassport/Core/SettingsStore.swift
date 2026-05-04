import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var preferredUnits: MeasurementUnits {
        didSet { UserDefaults.standard.set(preferredUnits.rawValue, forKey: Keys.units) }
    }

    /// Master toggle for travel-deadline reminders. Defaults ON. Flipping
    /// to OFF triggers `ReminderScheduler.cancelEverything()` from the
    /// Settings view.
    @Published var remindersEnabled: Bool {
        didSet { UserDefaults.standard.set(remindersEnabled, forKey: Keys.remindersEnabled) }
    }

    enum MeasurementUnits: String, CaseIterable, Identifiable {
        case imperial, metric
        var id: String { rawValue }
        var label: String { self == .imperial ? "Pounds & inches" : "Kilograms & cm" }
    }

    private enum Keys {
        static let units = "petpassport.units"
        static let remindersEnabled = "petpassport.remindersEnabled"
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Keys.units) ?? MeasurementUnits.imperial.rawValue
        self.preferredUnits = MeasurementUnits(rawValue: raw) ?? .imperial

        // Default ON for new installs. UserDefaults.bool returns false for
        // missing keys, so we use object(forKey:) to distinguish.
        if let stored = UserDefaults.standard.object(forKey: Keys.remindersEnabled) as? Bool {
            self.remindersEnabled = stored
        } else {
            self.remindersEnabled = true
        }
    }
}
