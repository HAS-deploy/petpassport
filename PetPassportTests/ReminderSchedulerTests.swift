import XCTest
@testable import PetPassport

final class ReminderSchedulerTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.timeZone = TimeZone(identifier: "UTC")
        c.year = y; c.month = m; c.day = d
        return cal.date(from: c)!
    }

    private let samplePet = PetProfile(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Bella", species: .dog, breed: "Beagle",
        birthDate: Date(timeIntervalSince1970: 0)
    )

    // MARK: - Plan: pure expansion

    /// 5 timeline items × 4 standard offsets = up to 20 reminders. Where
    /// every fire date is in the future relative to `now`, we get exactly
    /// 20.
    func test_planExpandsFiveItemsAcrossFourOffsetsToTwentyReminders() throws {
        // Build five items, all >30 days in the future so every offset
        // (30/7/1/0) is in the future.
        let now = day(2026, 06, 01)
        let items: [TimelineItem] = (0..<5).map { idx in
            let due = cal.date(byAdding: .day, value: 100 + idx * 5, to: now)!
            return TimelineItem(
                id: "item-\(idx)",
                dueBy: due,
                title: "Step \(idx)",
                detail: "Detail \(idx)",
                citation: nil,
                isPast: false
            )
        }
        let trip = ReminderScheduler.TripKey(petId: samplePet.id, destinationId: "FRA")
        let plan = ReminderScheduler.plan(items: items, tripKey: trip, existingIdentifiers: [], now: now)
        XCTAssertEqual(plan.toCreate.count, 20, "5 items × 4 offsets must produce 20 reminders when all fire dates are future")
        XCTAssertTrue(plan.toCancel.isEmpty)
        // Every identifier carries the trip prefix.
        for r in plan.toCreate {
            XCTAssertTrue(r.identifier.hasPrefix(trip.identifierPrefix))
        }
        // Every fire date is strictly after `now`.
        for r in plan.toCreate {
            XCTAssertGreaterThan(r.fireAt, now)
        }
    }

    /// Past-fire-times are filtered out of toCreate.
    func test_planSkipsOffsetsWhoseFireDateIsInThePast() throws {
        let now = day(2026, 06, 15)
        // Item due in 5 days. Offsets 30 and 7 produce fire dates in the
        // past relative to `now`; offsets 1 and 0 are still in the future.
        let item = TimelineItem(
            id: "soon", dueBy: cal.date(byAdding: .day, value: 5, to: now)!,
            title: "Soon", detail: "...", citation: nil, isPast: false
        )
        let trip = ReminderScheduler.TripKey(petId: samplePet.id, destinationId: "GBR")
        let plan = ReminderScheduler.plan(items: [item], tripKey: trip, now: now)
        XCTAssertEqual(plan.toCreate.count, 2)
        let offsets = Set(plan.toCreate.map(\.daysBefore))
        XCTAssertEqual(offsets, Set([1, 0]))
    }

    /// Identifier is deterministic for a given (trip, item, offset). That
    /// guarantee is what makes reconcile idempotent.
    func test_identifierIsDeterministic() {
        let trip = ReminderScheduler.TripKey(
            petId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            destinationId: "JPN"
        )
        let a = ReminderScheduler.identifier(tripKey: trip, itemId: "rabies", daysBefore: 7)
        let b = ReminderScheduler.identifier(tripKey: trip, itemId: "rabies", daysBefore: 7)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.hasPrefix(trip.identifierPrefix))
        XCTAssertTrue(a.hasSuffix("rabies.d7"))
    }

    // MARK: - Reconcile on departure-date change cancels + reschedules

    /// Departure date moves later → some old identifiers no longer match
    /// the new desired set → they go into `toCancel`, and the new
    /// identifiers (different fire times → still same id since id is a
    /// function of trip+item+offset, NOT of date) just stay. To force a
    /// real cancellation we change the *destination* (which changes the
    /// identifier prefix). For the date-change case the reconcile keeps
    /// the same ids and silently re-uses them — but `apply` reschedules
    /// because the *fireAt* differs.
    func test_planCancelsStaleTripIdentifiersWhenItemSetShrinks() {
        let trip = ReminderScheduler.TripKey(petId: samplePet.id, destinationId: "GBR")
        let dest = DestinationCatalog.all.first { $0.id == "GBR" }!
        let originalDeparture = day(2026, 12, 01)
        let now = day(2026, 06, 01)
        let originalItems = TimelineBuilder.build(destination: dest, pet: samplePet, departure: originalDeparture, now: now)
        let firstPlan = ReminderScheduler.plan(items: originalItems, tripKey: trip, existingIdentifiers: [], now: now)
        XCTAssertFalse(firstPlan.toCreate.isEmpty)

        // Pretend we scheduled them all on the system.
        let pendingAfterFirst = Set(firstPlan.toCreate.map(\.identifier))

        // Now move the departure date so close that some offsets fall in
        // the past — those reminders should be cancelled.
        let newDeparture = cal.date(byAdding: .day, value: 5, to: now)!
        let newItems = TimelineBuilder.build(destination: dest, pet: samplePet, departure: newDeparture, now: now)
        let secondPlan = ReminderScheduler.plan(
            items: newItems,
            tripKey: trip,
            existingIdentifiers: pendingAfterFirst,
            now: now
        )

        // Some of the originals no longer fit (offsets 30 and 7 from a
        // departure 5 days out are in the past) → they must be cancelled.
        XCTAssertFalse(secondPlan.toCancel.isEmpty,
                       "shrinking the timeline must produce cancellations for stale identifiers")
        // Every cancelled id was previously pending and belongs to this trip.
        for id in secondPlan.toCancel {
            XCTAssertTrue(id.hasPrefix(trip.identifierPrefix))
            XCTAssertTrue(pendingAfterFirst.contains(id))
        }
    }

    /// Destination change → identifier prefix changes → the OLD
    /// destination's identifiers belong to a DIFFERENT trip key, so plan
    /// for the new trip should NOT cancel them (different prefix). The
    /// view layer handles the previous-trip cleanup explicitly via
    /// `cancelAll(for:)` if needed; the per-trip plan is correctly scoped.
    func test_planForNewTripDoesNotTouchOtherTripsIdentifiers() {
        let oldTrip = ReminderScheduler.TripKey(petId: samplePet.id, destinationId: "GBR")
        let newTrip = ReminderScheduler.TripKey(petId: samplePet.id, destinationId: "FRA")
        let now = day(2026, 06, 01)
        let oldDest = DestinationCatalog.all.first { $0.id == "GBR" }!
        let newDest = DestinationCatalog.all.first { $0.id == "FRA" }!
        let departure = day(2026, 12, 01)
        let oldItems = TimelineBuilder.build(destination: oldDest, pet: samplePet, departure: departure, now: now)
        let oldPlan = ReminderScheduler.plan(items: oldItems, tripKey: oldTrip, existingIdentifiers: [], now: now)
        let pending = Set(oldPlan.toCreate.map(\.identifier))

        let newItems = TimelineBuilder.build(destination: newDest, pet: samplePet, departure: departure, now: now)
        let newPlan = ReminderScheduler.plan(items: newItems, tripKey: newTrip, existingIdentifiers: pending, now: now)

        // The new plan must NOT propose to cancel the old destination's
        // pending requests — they're scoped to a different prefix.
        XCTAssertTrue(newPlan.toCancel.isEmpty,
                       "plan() should only cancel identifiers belonging to its own trip prefix")
        // It DOES want to create new ones for the new prefix.
        XCTAssertFalse(newPlan.toCreate.isEmpty)
        for r in newPlan.toCreate {
            XCTAssertTrue(r.identifier.hasPrefix(newTrip.identifierPrefix))
        }
    }

    /// Re-running plan with the desired set already pending is a no-op.
    func test_planIsIdempotent() {
        let trip = ReminderScheduler.TripKey(petId: samplePet.id, destinationId: "CAN")
        let now = day(2026, 06, 01)
        let items: [TimelineItem] = [
            .init(id: "x", dueBy: cal.date(byAdding: .day, value: 60, to: now)!,
                  title: "X", detail: "...", citation: nil, isPast: false)
        ]
        let first = ReminderScheduler.plan(items: items, tripKey: trip, existingIdentifiers: [], now: now)
        let pending = Set(first.toCreate.map(\.identifier))
        let second = ReminderScheduler.plan(items: items, tripKey: trip, existingIdentifiers: pending, now: now)
        XCTAssertTrue(second.toCreate.isEmpty)
        XCTAssertTrue(second.toCancel.isEmpty)
    }

    // MARK: - Toggle-off cancels everything

    /// When the user turns the master toggle off, `cancelEverything()`
    /// must remove every identifier that begins with our app's reminder
    /// prefix — across every trip — and never touch identifiers belonging
    /// to other apps. We test this at the planning level: every
    /// identifier we ever emit starts with `"petpassport.reminder."`.
    func test_everyEmittedIdentifierCarriesAppPrefix() {
        let trips = [
            ReminderScheduler.TripKey(petId: UUID(), destinationId: "GBR"),
            ReminderScheduler.TripKey(petId: UUID(), destinationId: "JPN"),
            ReminderScheduler.TripKey(petId: UUID(), destinationId: "FRA")
        ]
        let now = day(2026, 06, 01)
        let item = TimelineItem(
            id: "rabies", dueBy: cal.date(byAdding: .day, value: 60, to: now)!,
            title: "Rabies", detail: "...", citation: nil, isPast: false
        )
        for trip in trips {
            let plan = ReminderScheduler.plan(items: [item], tripKey: trip, now: now)
            for r in plan.toCreate {
                XCTAssertTrue(r.identifier.hasPrefix("petpassport.reminder."),
                              "every reminder identifier must carry the app prefix so cancelEverything() can scope correctly")
            }
        }
    }

    // MARK: - Real catalog smoke test (UK 4 items × 4 offsets ≤ 16)

    /// For a real destination (UK) and a far-future departure, we expect
    /// at most 4 items × 4 offsets = 16 reminders.
    func test_realUKDestinationProducesAtMostSixteenReminders() {
        let dest = DestinationCatalog.all.first { $0.id == "GBR" }!
        let now = day(2026, 01, 01)
        let departure = day(2026, 12, 01)
        let items = TimelineBuilder.build(destination: dest, pet: samplePet, departure: departure, now: now)
        XCTAssertEqual(items.count, 4)
        let trip = ReminderScheduler.TripKey(petId: samplePet.id, destinationId: dest.id)
        let plan = ReminderScheduler.plan(items: items, tripKey: trip, now: now)
        XCTAssertLessThanOrEqual(plan.toCreate.count, 16)
        XCTAssertGreaterThan(plan.toCreate.count, 0)
    }
}
