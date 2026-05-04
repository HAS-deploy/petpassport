import SwiftUI

struct TimelineResultView: View {
    let pet: PetProfile
    let destination: Destination
    let departure: Date

    @EnvironmentObject private var settings: SettingsStore
    @State private var scheduledCount: Int = 0
    @State private var permissionDenied: Bool = false
    @State private var generatedTrigger = 0

    private var items: [TimelineItem] {
        TimelineBuilder.build(destination: destination, pet: pet, departure: departure)
    }

    private var tripKey: ReminderScheduler.TripKey {
        .init(petId: pet.id, destinationId: destination.id)
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
            if settings.remindersEnabled && scheduledCount > 0 {
                Section {
                    Label {
                        Text("\(scheduledCount) reminder\(scheduledCount == 1 ? "" : "s") scheduled for this trip.")
                            .font(.footnote)
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            if settings.remindersEnabled && permissionDenied {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications are off")
                                .font(.footnote.bold())
                            Text("Open Settings → Notifications → My Pet Passport to turn deadline reminders on.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(.orange)
                    }
                }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: TimelineShareText.summary(
                        pet: pet,
                        destination: destination,
                        departure: departure,
                        items: items
                    ),
                    subject: Text("\(pet.name) — \(destination.name) compliance timeline")
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .task {
            // Treat first appearance of TimelineResultView as the
            // "finalization" moment. This is the first time we'll ever
            // ask for notification permission.
            await reconcileReminders()
            generatedTrigger &+= 1
        }
        .hapticSuccess(trigger: generatedTrigger)
        .onChange(of: departure) { _ in
            Task { await reconcileReminders() }
        }
        .onChange(of: destination) { _ in
            Task { await reconcileReminders() }
        }
    }

    private func reconcileReminders() async {
        guard settings.remindersEnabled else {
            await ReminderScheduler.cancelAll(for: tripKey)
            scheduledCount = 0
            return
        }
        let count = await ReminderScheduler.apply(items: items, tripKey: tripKey)
        scheduledCount = count
        permissionDenied = await ReminderScheduler.isDenied()
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
