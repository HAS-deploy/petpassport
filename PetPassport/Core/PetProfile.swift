import Foundation

struct PetProfile: Identifiable, Codable, Hashable {
    enum Species: String, Codable, CaseIterable, Identifiable {
        case dog, cat, ferret
        var id: String { rawValue }
        var label: String {
            switch self {
            case .dog: return "Dog"
            case .cat: return "Cat"
            case .ferret: return "Ferret"
            }
        }
    }

    let id: UUID
    var name: String
    var species: Species
    var breed: String
    var birthDate: Date
    var microchipId: String?
    var rabiesVaccineDate: Date?

    init(id: UUID = UUID(),
         name: String,
         species: Species,
         breed: String = "",
         birthDate: Date,
         microchipId: String? = nil,
         rabiesVaccineDate: Date? = nil) {
        self.id = id
        self.name = name
        self.species = species
        self.breed = breed
        self.birthDate = birthDate
        self.microchipId = microchipId
        self.rabiesVaccineDate = rabiesVaccineDate
    }

    var ageInMonths: Int {
        let comps = Calendar.current.dateComponents([.month], from: birthDate, to: Date())
        return max(0, comps.month ?? 0)
    }
}

@MainActor
final class PetProfileStore: ObservableObject {
    @Published private(set) var pets: [PetProfile] = [] {
        didSet { persist() }
    }

    private let storageKey = "petpassport.pets"

    init() { load() }

    func add(_ pet: PetProfile) { pets.append(pet) }
    func remove(_ pet: PetProfile) { pets.removeAll { $0.id == pet.id } }
    func replace(_ pet: PetProfile) {
        if let i = pets.firstIndex(where: { $0.id == pet.id }) { pets[i] = pet }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(pets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PetProfile].self, from: data) else { return }
        pets = decoded
    }
}
