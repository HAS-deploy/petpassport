import SwiftUI

struct TimelineSetupView: View {
    let pet: PetProfile
    let destination: Destination

    @State private var departure: Date = Date().addingTimeInterval(3600*24*60) // 2 months out

    var body: some View {
        Form {
            Section("Trip") {
                LabeledContent("Pet", value: pet.name)
                LabeledContent("Destination", value: destination.name)
                DatePicker("Departure", selection: $departure, in: Date()..., displayedComponents: .date)
            }

            if let earliest = TimelineBuilder.earliestPossibleDeparture(from: Date(), for: destination),
               earliest > departure {
                Section {
                    Label {
                        Text("The earliest realistic departure for \(destination.name) is \(earliest.formatted(date: .abbreviated, time: .omitted)). Earlier travel risks quarantine or denied entry.")
                            .font(.footnote)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                NavigationLink {
                    TimelineResultView(pet: pet, destination: destination, departure: departure)
                } label: {
                    Text("Build Timeline")
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                Text("Pet Passport summarizes publicly available import requirements. It is not legal advice and not a substitute for a USDA-accredited vet or your destination's customs agency.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Plan Trip")
        .navigationBarTitleDisplayMode(.inline)
    }
}
