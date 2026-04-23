import Foundation

/// Intentionally disabled. We declare NSPrivacyTracking=false in
/// PrivacyInfo.xcprivacy and "No data collected" on the App Privacy label.
/// If we later add analytics, this becomes a real client AND the privacy
/// manifest + App Privacy answers must be updated first.
enum AnalyticsClient {
    static func track(_ event: String, _ properties: [String: Any] = [:]) {
        #if DEBUG
        // Local-only dev diagnostic — never leaves the device.
        print("analytics: \(event) \(properties)")
        #endif
    }
}
