import SwiftUI

struct PetProfileEditor: View {
    enum Mode { case create, edit(PetProfile) }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var petStore: PetProfileStore

    let mode: Mode

    @State private var name = ""
    @State private var species: PetProfile.Species = .dog
    @State private var breed = ""
    @State private var birthDate = Date().addingTimeInterval(-3600*24*365)
    @State private var microchipId = ""
    @State private var rabiesVaccineDate: Date? = nil
    @State private var hasRabies = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Pet") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Species", selection: $species) {
                        ForEach(PetProfile.Species.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    TextField("Breed (optional)", text: $breed)
                        .textInputAutocapitalization(.words)
                    DatePicker("Birth date", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                }

                Section("Travel identifiers") {
                    TextField("Microchip ID (optional)", text: $microchipId)
                        .keyboardType(.asciiCapableNumberPad)
                        .autocorrectionDisabled()
                    Toggle("Rabies vaccine on file", isOn: $hasRabies)
                    if hasRabies {
                        DatePicker("Date administered",
                                   selection: Binding(get: { rabiesVaccineDate ?? Date() },
                                                      set: { rabiesVaccineDate = $0 }),
                                   in: ...Date(), displayedComponents: .date)
                    }
                }

                Section {
                    Text("Everything stays on this device. Pet Passport does not sync, upload, or share your data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: hydrate)
        }
    }

    private var titleText: String {
        if case .edit = mode { return "Edit Pet" }
        return "Add Pet"
    }

    private func hydrate() {
        if case .edit(let existing) = mode {
            name = existing.name
            species = existing.species
            breed = existing.breed
            birthDate = existing.birthDate
            microchipId = existing.microchipId ?? ""
            rabiesVaccineDate = existing.rabiesVaccineDate
            hasRabies = existing.rabiesVaccineDate != nil
        }
    }

    private func save() {
        let trimmedChip = microchipId.trimmingCharacters(in: .whitespaces)
        let rabies = hasRabies ? rabiesVaccineDate : nil
        switch mode {
        case .create:
            petStore.add(.init(name: name.trimmingCharacters(in: .whitespaces),
                               species: species,
                               breed: breed.trimmingCharacters(in: .whitespaces),
                               birthDate: birthDate,
                               microchipId: trimmedChip.isEmpty ? nil : trimmedChip,
                               rabiesVaccineDate: rabies))
        case .edit(let existing):
            petStore.replace(.init(id: existing.id,
                                   name: name.trimmingCharacters(in: .whitespaces),
                                   species: species,
                                   breed: breed.trimmingCharacters(in: .whitespaces),
                                   birthDate: birthDate,
                                   microchipId: trimmedChip.isEmpty ? nil : trimmedChip,
                                   rabiesVaccineDate: rabies))
        }
    }
}
