import Foundation

/// Central place to edit the app's paid tier. Kept tiny on purpose so the
/// factory template can be reused across apps by swapping one file.
enum PricingConfig {
    /// StoreKit product ID — must match Configuration.storekit + App Store Connect.
    static let proLifetimeProductID = "com.mypetpassport.app.pro.lifetime"

    /// What unlocks at Pro. Used by the paywall and benefits list.
    static let proBenefits: [String] = [
        "Timelines for every supported destination",
        "Detailed document + vaccination checklists",
        "Export compliance packet as PDF",
        "Up to 5 pet profiles",
        "Free updates as regulations change"
    ]

    /// Friendly price shown as a fallback if StoreKit.localizedPrice is missing.
    /// Keep in sync with ASC pricing; StoreKit wins at runtime.
    static let proFallbackDisplayPrice = "$9.99"

    /// Short hook shown above the CTA. No "unlock", "premium", or "subscribe" —
    /// we don't sell subscriptions and we don't want app-review friction.
    static let proHeadline = "One-time purchase. Forever yours."
    static let proSubheadline = "Plan your pet's travel without guessing the paperwork."
}
