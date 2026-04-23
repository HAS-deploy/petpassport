import XCTest
@testable import PetPassport

final class DestinationCatalogTests: XCTestCase {
    func test_everyDestinationHasAtLeastOneStep() throws {
        for d in DestinationCatalog.all {
            XCTAssertFalse(d.steps.isEmpty, "\(d.id) must have at least one compliance step")
        }
    }

    func test_freeTierHasExactlyThreeDestinations() throws {
        XCTAssertEqual(DestinationCatalog.forFreeTier().count, 3,
                       "Free tier should always be 3 destinations so the paywall math is consistent")
    }

    func test_everyStepIdIsUniqueWithinADestination() throws {
        for d in DestinationCatalog.all {
            let ids = d.steps.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "\(d.id) has duplicate step ids")
        }
    }

    func test_destinationIdsAreIso3Alpha() throws {
        for d in DestinationCatalog.all {
            XCTAssertEqual(d.id.count, 3, "\(d.id) must be ISO-3166 alpha-3")
            XCTAssertEqual(d.id, d.id.uppercased())
        }
    }
}
