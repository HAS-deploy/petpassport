import XCTest
@testable import PetPassport

@MainActor
final class PurchaseManagerTests: XCTestCase {
    /// PurchaseManager defaults to !isPro on a fresh install.
    func test_defaultStateIsNotPro() {
        // Ensure a clean slate for this test.
        UserDefaults.standard.removeObject(forKey: "petpassport.isPro")
        let m = PurchaseManager()
        XCTAssertFalse(m.isPro)
    }

    /// Cached pro state persists across instances via UserDefaults.
    func test_cachedProPersistsAcrossInstances() {
        UserDefaults.standard.set(true, forKey: "petpassport.isPro")
        defer { UserDefaults.standard.removeObject(forKey: "petpassport.isPro") }
        let m = PurchaseManager()
        XCTAssertTrue(m.isPro)
    }

    /// Pricing config product ID must match Configuration.storekit / ASC.
    func test_pricingConfigProductIdShape() {
        XCTAssertTrue(PricingConfig.proLifetimeProductID.hasPrefix("com.mypetpassport.app"))
        XCTAssertFalse(PricingConfig.proBenefits.isEmpty)
    }
}
