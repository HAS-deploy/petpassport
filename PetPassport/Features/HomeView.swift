import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var petStore: PetProfileStore
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var selectedPet: PetProfile?
    @State private var showingAddPet = false
    @State private var showingSettings = false

    var body: some View {
        List {
            Section("Your Pets") {
                ForEach(petStore.pets) { pet in
                    NavigationLink {
                        DestinationPickerView(pet: pet)
                    } label: {
                        PetRow(pet: pet)
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        petStore.remove(petStore.pets[i])
                    }
                }
                Button {
                    showingAddPet = true
                } label: {
                    Label("Add another pet", systemImage: "plus.circle")
                }
            }

            if !purchases.isPro {
                Section {
                    NavigationLink {
                        PaywallView()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unlock all destinations")
                                .font(.headline)
                            Text("Free trial covers Canada, Mexico, and the UK. Pro adds 7+ more.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pet Passport")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showingAddPet) {
            PetProfileEditor(mode: .create)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
    }
}

private struct PetRow: View {
    let pet: PetProfile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name).font(.headline)
                Text("\(pet.species.label) · \(pet.ageInMonths) months")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch pet.species {
        case .dog: return "pawprint.fill"
        case .cat: return "cat.fill"
        case .ferret: return "hare.fill"
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environmentObject(PurchaseManager())
        .environmentObject({
            let s = PetProfileStore()
            s.add(.init(name: "Biscuit", species: .dog, breed: "Beagle", birthDate: Date().addingTimeInterval(-3600*24*400)))
            return s
        }())
        .environmentObject(SettingsStore())
}
