import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var preferredUnits: MeasurementUnits {
        didSet { UserDefaults.standard.set(preferredUnits.rawValue, forKey: Keys.units) }
    }

    enum MeasurementUnits: String, CaseIterable, Identifiable {
        case imperial, metric
        var id: String { rawValue }
        var label: String { self == .imperial ? "Pounds & inches" : "Kilograms & cm" }
    }

    private enum Keys {
        static let units = "petpassport.units"
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Keys.units) ?? MeasurementUnits.imperial.rawValue
        self.preferredUnits = MeasurementUnits(rawValue: raw) ?? .imperial
    }
}
