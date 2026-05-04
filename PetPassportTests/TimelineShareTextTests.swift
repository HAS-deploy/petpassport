import XCTest
@testable import PetPassport

final class TimelineShareTextTests: XCTestCase {
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

    func test_summaryContainsPetAndDestinationHeader() throws {
        let dest = DestinationCatalog.all.first { $0.id == "GBR" }!
        let departure = day(2026, 9, 1)
        let items = TimelineBuilder.build(destination: dest, pet: samplePet, departure: departure, now: day(2026, 1, 1))
        let text = TimelineShareText.summary(pet: samplePet, destination: dest, departure: departure, items: items)
        XCTAssertTrue(text.contains("Biscuit"))
        XCTAssertTrue(text.contains("United Kingdom"))
        XCTAssertTrue(text.contains("2026"))
    }

    func test_summaryListsAllStepsAndAdvisory() throws {
        let dest = DestinationCatalog.all.first { $0.id == "MEX" }!
        let departure = day(2026, 7, 1)
        let items = TimelineBuilder.build(destination: dest, pet: samplePet, departure: departure, now: day(2026, 1, 1))
        let text = TimelineShareText.summary(pet: samplePet, destination: dest, departure: departure, items: items)
        for item in items {
            XCTAssertTrue(text.contains(item.title), "share text missing step: \(item.title)")
        }
        XCTAssertTrue(text.contains("Informational only"))
    }

    func test_summaryHasOneStepLinePerItem() throws {
        let dest = DestinationCatalog.all.first { $0.id == "CAN" }!
        let departure = day(2026, 6, 15)
        let items = TimelineBuilder.build(destination: dest, pet: samplePet, departure: departure, now: day(2026, 1, 1))
        let text = TimelineShareText.summary(pet: samplePet, destination: dest, departure: departure, items: items)
        for item in items {
            XCTAssertTrue(text.contains("— \(item.title)"),
                          "expected '— \(item.title)' delimiter line in share text")
        }
    }
}
