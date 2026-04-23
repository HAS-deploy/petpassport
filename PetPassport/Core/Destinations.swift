import Foundation

/// A country the user may want to travel to with their pet. Static for v1 —
/// regulations change, so we ship explicit `rulesUpdated` on every entry and
/// show it on the timeline. Free tier unlocks the top 3 most-searched; Pro
/// unlocks the full list.
struct Destination: Identifiable, Hashable {
    let id: String         // ISO-3166 alpha-3 code
    let name: String
    let flag: String       // emoji
    let requiresFreeTier: Bool
    let rulesUpdated: Date // display-only; triggers a "refresh" hint on stale data
    let steps: [ComplianceStep]
}

struct ComplianceStep: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    /// How many days before departure this must be complete.
    /// Negative means "at least X days before" (e.g., -21 = 21 days before).
    let leadTimeDays: Int
    let citation: String?  // link or doc reference
}

enum DestinationCatalog {
    static let freeTier: Set<String> = ["CAN", "MEX", "GBR"]

    static let all: [Destination] = [
        // Free-tier sample — keep these three populated for the basic flow.
        Destination(
            id: "CAN", name: "Canada", flag: "🇨🇦",
            requiresFreeTier: true, rulesUpdated: date("2026-01-15"),
            steps: [
                .init(id: "microchip", title: "ISO microchip implanted",
                      detail: "Most Canadian customs will accept a pre-existing microchip. If your pet does not already have an ISO-compliant chip, implant one before the rabies vaccine.",
                      leadTimeDays: -60, citation: "CFIA pet import guidance"),
                .init(id: "rabies", title: "Current rabies vaccine",
                      detail: "Must be valid on the date of entry. Puppies and kittens under 3 months are exempt — a vet letter is required.",
                      leadTimeDays: -30, citation: "CFIA – Importing pets"),
                .init(id: "cfia-form", title: "Veterinary health certificate",
                      detail: "Signed by a USDA-accredited vet within 10 days of travel. Not APHIS-endorsed — Canada does not require federal endorsement.",
                      leadTimeDays: -10, citation: "CFIA 5038")
            ]),
        Destination(
            id: "MEX", name: "Mexico", flag: "🇲🇽",
            requiresFreeTier: true, rulesUpdated: date("2026-02-05"),
            steps: [
                .init(id: "rabies", title: "Rabies vaccine proof",
                      detail: "Original or copy of the vaccination certificate. No specific lead time — just must be current.",
                      leadTimeDays: -30, citation: "SENASICA"),
                .init(id: "exam", title: "Clinical exam within 15 days",
                      detail: "SENASICA accepts a clinical exam confirming the pet is free of external parasites and good health. USDA endorsement NOT required.",
                      leadTimeDays: -15, citation: "SENASICA pet import"),
                .init(id: "declare", title: "Declare at customs",
                      detail: "Verbally declare the pet. Keep the rabies cert and exam paperwork accessible.",
                      leadTimeDays: 0, citation: nil)
            ]),
        Destination(
            id: "GBR", name: "United Kingdom", flag: "🇬🇧",
            requiresFreeTier: true, rulesUpdated: date("2026-03-01"),
            steps: [
                .init(id: "microchip", title: "ISO 11784/11785 microchip",
                      detail: "Implanted BEFORE the rabies vaccine. If the vaccine was given first, the pet will be quarantined on arrival.",
                      leadTimeDays: -90, citation: "DEFRA pet travel"),
                .init(id: "rabies", title: "Rabies vaccine + 21-day wait",
                      detail: "The 21-day wait begins the day after the shot. Travelling before day 22 = quarantine.",
                      leadTimeDays: -22, citation: "DEFRA"),
                .init(id: "ahc", title: "Animal Health Certificate",
                      detail: "Must be issued by a USDA-accredited vet and then APHIS-endorsed within 10 days of UK entry.",
                      leadTimeDays: -10, citation: "APHIS Form 7001 + UK AHC"),
                .init(id: "tapeworm", title: "Tapeworm treatment (dogs only)",
                      detail: "Administered 24–120 hours before arrival, logged on the AHC.",
                      leadTimeDays: -2, citation: "DEFRA tapeworm req")
            ]),

        // Pro-tier destinations (same shape, less verbose here — fill out later)
        Destination(
            id: "JPN", name: "Japan", flag: "🇯🇵",
            requiresFreeTier: false, rulesUpdated: date("2026-02-20"),
            steps: [
                .init(id: "microchip", title: "ISO microchip", detail: "Implanted before the first rabies vaccine.", leadTimeDays: -210, citation: "MAFF Japan"),
                .init(id: "rabies1", title: "First rabies vaccine", detail: "Must be AFTER the microchip.", leadTimeDays: -180, citation: "MAFF"),
                .init(id: "rabies2", title: "Second rabies vaccine", detail: "30+ days after the first.", leadTimeDays: -150, citation: "MAFF"),
                .init(id: "titer", title: "Blood titer (FAVN) test", detail: "Blood drawn 30+ days after the 2nd rabies shot. Sent to a MAFF-approved lab.", leadTimeDays: -180, citation: "FAVN RNATT"),
                .init(id: "wait", title: "180-day wait period", detail: "From the date the blood was drawn. No travel before day 180.", leadTimeDays: -180, citation: "MAFF"),
                .init(id: "advance", title: "Advance notification (40 days)", detail: "Submit AQS Form A to the destination airport's Animal Quarantine Service.", leadTimeDays: -40, citation: "AQS Form A"),
                .init(id: "ahc", title: "USDA-endorsed Form AC", detail: "Within 10 days of departure.", leadTimeDays: -10, citation: "Japan Form AC")
            ]),
        Destination(
            id: "AUS", name: "Australia", flag: "🇦🇺",
            requiresFreeTier: false, rulesUpdated: date("2026-03-01"),
            steps: [
                .init(id: "microchip", title: "ISO microchip", detail: "Permanent, before vaccines.", leadTimeDays: -365, citation: "DAFF"),
                .init(id: "rabies", title: "Rabies vaccine", detail: "Within 12 months of travel.", leadTimeDays: -365, citation: "DAFF"),
                .init(id: "titer", title: "RNATT blood test", detail: "180+ days before travel.", leadTimeDays: -180, citation: "DAFF RNATT"),
                .init(id: "permit", title: "Import permit", detail: "Apply via BICON at least 42 days before travel.", leadTimeDays: -42, citation: "BICON"),
                .init(id: "quarantine", title: "10-day mandatory quarantine", detail: "At Mickleham, Melbourne. Reserved in advance.", leadTimeDays: 0, citation: "DAFF PEQ")
            ]),
        Destination(
            id: "DEU", name: "Germany (EU)", flag: "🇩🇪",
            requiresFreeTier: false, rulesUpdated: date("2026-02-15"),
            steps: [
                .init(id: "microchip", title: "ISO microchip before vaccine", detail: "", leadTimeDays: -60, citation: "EU Reg 576/2013"),
                .init(id: "rabies", title: "Rabies vaccine + 21-day wait", detail: "", leadTimeDays: -22, citation: "EU"),
                .init(id: "ehc", title: "USDA-endorsed EU Health Certificate", detail: "Within 10 days of entry.", leadTimeDays: -10, citation: "APHIS EU")
            ]),
        Destination(
            id: "FRA", name: "France (EU)", flag: "🇫🇷",
            requiresFreeTier: false, rulesUpdated: date("2026-02-15"),
            steps: [
                .init(id: "microchip", title: "ISO microchip before vaccine", detail: "", leadTimeDays: -60, citation: "EU Reg 576/2013"),
                .init(id: "rabies", title: "Rabies vaccine + 21-day wait", detail: "", leadTimeDays: -22, citation: "EU"),
                .init(id: "ehc", title: "USDA-endorsed EU Health Certificate", detail: "Within 10 days of entry.", leadTimeDays: -10, citation: "APHIS EU")
            ]),
        Destination(
            id: "NZL", name: "New Zealand", flag: "🇳🇿",
            requiresFreeTier: false, rulesUpdated: date("2026-01-28"),
            steps: [
                .init(id: "microchip", title: "ISO microchip", detail: "", leadTimeDays: -365, citation: "MPI NZ"),
                .init(id: "rabies", title: "Rabies vaccine", detail: "", leadTimeDays: -365, citation: "MPI"),
                .init(id: "titer", title: "Blood titer test", detail: "180+ days before entry.", leadTimeDays: -180, citation: "MPI"),
                .init(id: "permit", title: "Import permit", detail: "Required. Apply ≥ 30 days out.", leadTimeDays: -30, citation: "MPI"),
                .init(id: "quarantine", title: "10-day quarantine at entry", detail: "Auckland PAQF.", leadTimeDays: 0, citation: "MPI PAQF")
            ]),
        Destination(
            id: "IRL", name: "Ireland (EU)", flag: "🇮🇪",
            requiresFreeTier: false, rulesUpdated: date("2026-02-15"),
            steps: [
                .init(id: "microchip", title: "ISO microchip", detail: "", leadTimeDays: -60, citation: "DAFM"),
                .init(id: "rabies", title: "Rabies + 21-day wait", detail: "", leadTimeDays: -22, citation: "EU"),
                .init(id: "ehc", title: "EU Health Cert + APHIS endorsement", detail: "", leadTimeDays: -10, citation: "APHIS EU"),
                .init(id: "tapeworm", title: "Tapeworm treatment (dogs)", detail: "24–120h before arrival.", leadTimeDays: -2, citation: "DAFM")
            ]),
        Destination(
            id: "CHE", name: "Switzerland", flag: "🇨🇭",
            requiresFreeTier: false, rulesUpdated: date("2026-01-20"),
            steps: [
                .init(id: "microchip", title: "ISO microchip before vaccine", detail: "", leadTimeDays: -60, citation: "BLV"),
                .init(id: "rabies", title: "Rabies + 21-day wait", detail: "", leadTimeDays: -22, citation: "BLV"),
                .init(id: "ehc", title: "USDA-endorsed Swiss health cert", detail: "", leadTimeDays: -10, citation: "APHIS Switzerland")
            ])
    ]

    static func forFreeTier() -> [Destination] {
        all.filter { $0.requiresFreeTier }
    }
}

private func date(_ iso: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(identifier: "UTC")
    return f.date(from: iso) ?? Date()
}
