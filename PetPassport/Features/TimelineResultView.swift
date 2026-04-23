import SwiftUI

struct TimelineResultView: View {
    let pet: PetProfile
    let destination: Destination
    let departure: Date

    private var items: [TimelineItem] {
        TimelineBuilder.build(destination: destination, pet: pet, departure: departure)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(pet.name) → \(destination.flag) \(destination.name)")
                        .font(.title3.bold())
                    Text("Departure \(departure.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Section("Timeline") {
                ForEach(items) { item in
                    TimelineRow(item: item)
                }
            }
            Section {
                Text("Ship this timeline to your vet 3+ weeks before the first action date. Pet Passport is informational only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Compliance Timeline")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TimelineRow: View {
    let item: TimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.dueBy.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.bold())
                    .foregroundStyle(item.isPast ? .red : .secondary)
                Text(item.isPast ? "past due" : relativeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 96, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline)
                Text(item.detail).font(.caption)
                    .foregroundStyle(.secondary)
                if let cite = item.citation {
                    Text(cite)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var relativeLabel: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: item.dueBy).day ?? 0
        if days == 0 { return "today" }
        return days > 0 ? "in \(days)d" : "\(-days)d ago"
    }
}
