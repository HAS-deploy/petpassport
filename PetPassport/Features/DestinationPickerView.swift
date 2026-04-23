import SwiftUI

struct DestinationPickerView: View {
    let pet: PetProfile
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var showingPaywall = false

    var body: some View {
        List {
            Section("Included free") {
                ForEach(DestinationCatalog.all.filter { $0.requiresFreeTier }) { d in
                    NavigationLink {
                        TimelineSetupView(pet: pet, destination: d)
                    } label: {
                        DestinationRow(destination: d, locked: false)
                    }
                }
            }

            Section("Pro destinations") {
                ForEach(DestinationCatalog.all.filter { !$0.requiresFreeTier }) { d in
                    if purchases.isPro {
                        NavigationLink {
                            TimelineSetupView(pet: pet, destination: d)
                        } label: {
                            DestinationRow(destination: d, locked: false)
                        }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            DestinationRow(destination: d, locked: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Where to?")
        .sheet(isPresented: $showingPaywall) {
            NavigationStack { PaywallView() }
        }
    }
}

private struct DestinationRow: View {
    let destination: Destination
    let locked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(destination.flag).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.name).font(.headline)
                Text("\(destination.steps.count) compliance steps · rules updated \(destination.rulesUpdated.formatted(.dateTime.month(.abbreviated).year()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if locked {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
