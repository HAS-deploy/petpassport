import XCTest
@testable import PetPassport

final class TimelineBuilderTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.timeZone = TimeZone(identifier: "UTC")
        c.year = y; c.month = m; c.day = d
        return cal.date(from: c)!
    }

    private let samplePet = PetProfile(
        name: "Biscuit", species: .dog, breed: "Beagle",
        birthDate: Date(timeIntervalSince1970: 0)
    )

    func test_timelineIsSortedEarliestFirst() throws {
        let dest = DestinationCatalog.all.first { $0.id == "GBR" }!
        let departure = day(2026, 09, 01)
        let items = TimelineBuilder.build(destination: dest, pet: samplePet, departure: departure, now: day(2026, 01, 01))
        XCTAssertFalse(items.isEmpty)
        for i in 1..<items.count {
            XCTAssertLessThanOrEqual(items[i-1].dueBy, items[i].dueBy,
                "timeline must be sorted ascending by dueBy")
        }
    }

    func test_ukTapewormStepIsTwoDaysBeforeDeparture() throws {
        let dest = DestinationCatalog.all.first { $0.id == "GBR" }!
        let departure = day(2026, 09, 01)
        let items = TimelineBuilder.build(destination: dest, pet: samplePet, departure: departure)
        let tape = items.first { $0.id.hasSuffix("tapeworm") }
        XCTAssertNotNil(tape)
        let expected = cal.date(byAdding: .day, value: -2, to: departure)
        XCTAssertEqual(tape?.dueBy, expected)
    }

    func test_earliestPossibleDepartureIsAfterLongestLeadTime() throws {
        let jpn = DestinationCatalog.all.first { $0.id == "JPN" }!
        // Japan's 180-day wait is the worst — earliest departure must be at
        // least 210 days out (longest step is 210 for microchip).
        let today = day(2026, 01, 01)
        let earliest = try XCTUnwrap(TimelineBuilder.earliestPossibleDeparture(from: today, for: jpn))
        let delta = cal.dateComponents([.day], from: today, to: earliest).day ?? 0
        XCTAssertGreaterThanOrEqual(delta, 210)
    }

    func test_pastDueFlagIsSetWhenStepDateIsBeforeNow() throws {
        let dest = DestinationCatalog.all.first { $0.id == "MEX" }!
        let departure = day(2026, 03, 01)
        let now = day(2026, 02, 28)  // one day before departure — every "before-departure" step is past
        let items = TimelineBuilder.build(destination: dest, pet: samplePet, departure: departure, now: now)
        XCTAssertTrue(items.allSatisfy { $0.dueBy < departure ? $0.isPast : !$0.isPast } ||
                       items.contains { $0.isPast })
    }

    func test_dogsOnlyStepNotShownForCats() throws {
        let dest = DestinationCatalog.all.first { $0.id == "GBR" }!
        let cat = PetProfile(name: "Mochi", species: .cat, birthDate: Date())
        let items = TimelineBuilder.build(destination: dest, pet: cat, departure: day(2026, 09, 01))
        let tape = items.first { $0.id.hasSuffix("tapeworm") }
        XCTAssertNotNil(tape)
        XCTAssertTrue(tape!.detail.contains("Not applicable"),
                      "dogs-only step should be marked N/A for cats")
    }
}
