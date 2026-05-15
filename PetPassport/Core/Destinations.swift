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
    let citation: String?  // display label for the source
    /// Authoritative source URL for the citation, when one exists. Rendered
    /// as a tappable Link in the timeline so the user can verify the rule
    /// against APHIS, GOV.UK, CFIA, MAFF, DAFF, MPI, DAFM, BLV, SENASICA, etc.
    let citationURL: URL?

    init(id: String,
         title: String,
         detail: String,
         leadTimeDays: Int,
         citation: String?,
         citationURL: URL? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.leadTimeDays = leadTimeDays
        self.citation = citation
        self.citationURL = citationURL
    }
}

enum DestinationCatalog {
    static let freeTier: Set<String> = ["CAN", "MEX", "GBR"]

    // Authoritative source URLs — kept here as named constants so audit
    // tooling can grep for them and so the link list can be updated in one
    // place when an agency rotates a slug.
    private static let cfiaPets = URL(string: "https://inspection.canada.ca/animal-health/terrestrial-animals/imports/non-commercial/eng/1326600389775/1326600500578")!
    private static let cfiaForm = URL(string: "https://inspection.canada.ca/about-cfia/forms/eng/1378241522935/1378241675381")!
    private static let senasica = URL(string: "https://www.gob.mx/senasica/en/articulos/requirements-to-import-pets-to-mexico")!
    private static let defraPetTravel = URL(string: "https://www.gov.uk/taking-your-pet-abroad")!
    private static let defraAHC = URL(string: "https://www.gov.uk/guidance/pet-travel-to-europe-from-1-january-2021")!
    private static let aphisPetTravel = URL(string: "https://www.aphis.usda.gov/pet-travel")!
    private static let aphisEU = URL(string: "https://www.aphis.usda.gov/pet-travel/european-union")!
    private static let aphisJapan = URL(string: "https://www.aphis.usda.gov/pet-travel/japan")!
    private static let aphisSwitzerland = URL(string: "https://www.aphis.usda.gov/pet-travel/switzerland")!
    private static let maffJapan = URL(string: "https://www.maff.go.jp/aqs/english/animal/dog/import-other.html")!
    private static let daff = URL(string: "https://www.agriculture.gov.au/biosecurity-trade/cats-dogs")!
    private static let dafmIreland = URL(string: "https://www.gov.ie/en/service/9d0653-bringing-your-pet-into-ireland/")!
    private static let blvSwitzerland = URL(string: "https://www.blv.admin.ch/blv/en/home/tiere/reisen-mit-heimtieren/heimtierausweis.html")!
    private static let mpiNZ = URL(string: "https://www.mpi.govt.nz/bring-send-to-nz/pets-to-new-zealand/")!

    static let all: [Destination] = [
        // Free-tier sample — keep these three populated for the basic flow.
        Destination(
            id: "CAN", name: "Canada", flag: "🇨🇦",
            requiresFreeTier: true, rulesUpdated: date("2026-01-15"),
            steps: [
                .init(id: "microchip", title: "ISO microchip implanted",
                      detail: "Most Canadian customs will accept a pre-existing microchip. If your pet does not already have an ISO-compliant chip, implant one before the rabies vaccine.",
                      leadTimeDays: -60, citation: "CFIA pet import guidance",
                      citationURL: cfiaPets),
                .init(id: "rabies", title: "Current rabies vaccine",
                      detail: "Must be valid on the date of entry. Puppies and kittens under 3 months are exempt — a vet letter is required.",
                      leadTimeDays: -30, citation: "CFIA – Importing pets",
                      citationURL: cfiaPets),
                .init(id: "cfia-form", title: "Veterinary health certificate",
                      detail: "Signed by a USDA-accredited vet within 10 days of travel. Not APHIS-endorsed — Canada does not require federal endorsement.",
                      leadTimeDays: -10, citation: "CFIA 5038",
                      citationURL: cfiaForm)
            ]),
        Destination(
            id: "MEX", name: "Mexico", flag: "🇲🇽",
            requiresFreeTier: true, rulesUpdated: date("2026-02-05"),
            steps: [
                .init(id: "rabies", title: "Rabies vaccine proof",
                      detail: "Original or copy of the vaccination certificate. No specific lead time — just must be current.",
                      leadTimeDays: -30, citation: "SENASICA",
                      citationURL: senasica),
                .init(id: "exam", title: "Clinical exam within 15 days",
                      detail: "SENASICA accepts a clinical exam confirming the pet is free of external parasites and good health. USDA endorsement NOT required.",
                      leadTimeDays: -15, citation: "SENASICA pet import",
                      citationURL: senasica),
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
                      leadTimeDays: -90, citation: "DEFRA pet travel",
                      citationURL: defraPetTravel),
                .init(id: "rabies", title: "Rabies vaccine + 21-day wait",
                      detail: "The 21-day wait begins the day after the shot. Travelling before day 22 = quarantine.",
                      leadTimeDays: -22, citation: "DEFRA",
                      citationURL: defraPetTravel),
                .init(id: "ahc", title: "Animal Health Certificate",
                      detail: "Must be issued by a USDA-accredited vet and then APHIS-endorsed within 10 days of UK entry.",
                      leadTimeDays: -10, citation: "APHIS Form 7001 + UK AHC",
                      citationURL: aphisPetTravel),
                .init(id: "tapeworm", title: "Tapeworm treatment (dogs only)",
                      detail: "Administered 24–120 hours before arrival, logged on the AHC.",
                      leadTimeDays: -2, citation: "DEFRA tapeworm req",
                      citationURL: defraAHC)
            ]),

        // Pro-tier destinations
        Destination(
            id: "JPN", name: "Japan", flag: "🇯🇵",
            requiresFreeTier: false, rulesUpdated: date("2026-02-20"),
            steps: [
                .init(id: "microchip", title: "ISO microchip", detail: "Implanted before the first rabies vaccine.", leadTimeDays: -210, citation: "MAFF Japan", citationURL: maffJapan),
                .init(id: "rabies1", title: "First rabies vaccine", detail: "Must be AFTER the microchip.", leadTimeDays: -180, citation: "MAFF", citationURL: maffJapan),
                .init(id: "rabies2", title: "Second rabies vaccine", detail: "30+ days after the first.", leadTimeDays: -150, citation: "MAFF", citationURL: maffJapan),
                .init(id: "titer", title: "Blood titer (FAVN) test", detail: "Blood drawn 30+ days after the 2nd rabies shot. Sent to a MAFF-approved lab.", leadTimeDays: -180, citation: "FAVN RNATT", citationURL: maffJapan),
                .init(id: "wait", title: "180-day wait period", detail: "From the date the blood was drawn. No travel before day 180.", leadTimeDays: -180, citation: "MAFF", citationURL: maffJapan),
                .init(id: "advance", title: "Advance notification (40 days)", detail: "Submit AQS Form A to the destination airport's Animal Quarantine Service.", leadTimeDays: -40, citation: "AQS Form A", citationURL: maffJapan),
                .init(id: "ahc", title: "USDA-endorsed Form AC", detail: "Within 10 days of departure.", leadTimeDays: -10, citation: "Japan Form AC", citationURL: aphisJapan)
            ]),
        Destination(
            id: "AUS", name: "Australia", flag: "🇦🇺",
            requiresFreeTier: false, rulesUpdated: date("2026-03-01"),
            steps: [
                .init(id: "microchip", title: "ISO microchip", detail: "Permanent, before vaccines.", leadTimeDays: -365, citation: "DAFF", citationURL: daff),
                .init(id: "rabies", title: "Rabies vaccine", detail: "Within 12 months of travel.", leadTimeDays: -365, citation: "DAFF", citationURL: daff),
                .init(id: "titer", title: "RNATT blood test", detail: "180+ days before travel.", leadTimeDays: -180, citation: "DAFF RNATT", citationURL: daff),
                .init(id: "permit", title: "Import permit", detail: "Apply via BICON at least 42 days before travel.", leadTimeDays: -42, citation: "BICON", citationURL: daff),
                .init(id: "quarantine", title: "10-day mandatory quarantine", detail: "At Mickleham, Melbourne. Reserved in advance.", leadTimeDays: 0, citation: "DAFF PEQ", citationURL: daff)
            ]),
        Destination(
            id: "DEU", name: "Germany (EU)", flag: "🇩🇪",
            requiresFreeTier: false, rulesUpdated: date("2026-02-15"),
            steps: [
                .init(id: "microchip", title: "ISO microchip before vaccine",
                      detail: "ISO 11784/11785 compliant chip. Must be implanted BEFORE the rabies vaccine — if the vaccine is given first, the EU treats it as if the pet were unvaccinated and you must wait and re-vaccinate.",
                      leadTimeDays: -60, citation: "EU Reg 576/2013",
                      citationURL: aphisEU),
                .init(id: "rabies", title: "Rabies vaccine + 21-day wait",
                      detail: "Inactivated rabies vaccine administered after the microchip. Entry to Germany / the EU is permitted only after a 21-day wait from the date of the primary vaccination. Booster shots do not restart the clock.",
                      leadTimeDays: -22, citation: "EU pet travel scheme",
                      citationURL: aphisEU),
                .init(id: "ehc", title: "USDA-endorsed EU Health Certificate",
                      detail: "EU Annex IV health certificate, issued by a USDA-accredited vet and APHIS-endorsed within 10 days of entry. Valid for entry into the EU for 10 days, then for onward intra-EU travel for 4 months.",
                      leadTimeDays: -10, citation: "APHIS EU",
                      citationURL: aphisEU)
            ]),
        Destination(
            id: "FRA", name: "France (EU)", flag: "🇫🇷",
            requiresFreeTier: false, rulesUpdated: date("2026-02-15"),
            steps: [
                .init(id: "microchip", title: "ISO microchip before vaccine",
                      detail: "ISO 11784/11785 compliant chip implanted BEFORE the rabies vaccine. France enforces this strictly at CDG and Orly — a vaccine dated before the chip will fail inspection.",
                      leadTimeDays: -60, citation: "EU Reg 576/2013",
                      citationURL: aphisEU),
                .init(id: "rabies", title: "Rabies vaccine + 21-day wait",
                      detail: "Inactivated rabies vaccine administered after the microchip. Entry into France is permitted only after a 21-day wait from the date of the primary vaccination.",
                      leadTimeDays: -22, citation: "EU pet travel scheme",
                      citationURL: aphisEU),
                .init(id: "ehc", title: "USDA-endorsed EU Health Certificate",
                      detail: "EU Annex IV health certificate, issued by a USDA-accredited vet and APHIS-endorsed within 10 days of entry into France.",
                      leadTimeDays: -10, citation: "APHIS EU",
                      citationURL: aphisEU)
            ]),
        Destination(
            id: "NZL", name: "New Zealand", flag: "🇳🇿",
            requiresFreeTier: false, rulesUpdated: date("2026-01-28"),
            steps: [
                .init(id: "microchip", title: "ISO microchip",
                      detail: "ISO 11784/11785 compliant chip implanted before the rabies vaccine. MPI inspectors will read the chip on arrival at Auckland.",
                      leadTimeDays: -365, citation: "MPI NZ",
                      citationURL: mpiNZ),
                .init(id: "rabies", title: "Rabies vaccine",
                      detail: "Inactivated rabies vaccine administered after the microchip. New Zealand requires a current rabies vaccination certificate; the FAVN/RNATT titer below must be drawn at least 3 months after this vaccine.",
                      leadTimeDays: -365, citation: "MPI",
                      citationURL: mpiNZ),
                .init(id: "titer", title: "Blood titer test", detail: "180+ days before entry.", leadTimeDays: -180, citation: "MPI", citationURL: mpiNZ),
                .init(id: "permit", title: "Import permit", detail: "Required. Apply ≥ 30 days out.", leadTimeDays: -30, citation: "MPI", citationURL: mpiNZ),
                .init(id: "quarantine", title: "10-day quarantine at entry", detail: "Auckland PAQF.", leadTimeDays: 0, citation: "MPI PAQF", citationURL: mpiNZ)
            ]),
        Destination(
            id: "IRL", name: "Ireland (EU)", flag: "🇮🇪",
            requiresFreeTier: false, rulesUpdated: date("2026-02-15"),
            steps: [
                .init(id: "microchip", title: "ISO microchip",
                      detail: "ISO 11784/11785 compliant chip implanted BEFORE the rabies vaccine. Required by EU Regulation 576/2013 and enforced by DAFM at Dublin.",
                      leadTimeDays: -60, citation: "DAFM",
                      citationURL: dafmIreland),
                .init(id: "rabies", title: "Rabies + 21-day wait",
                      detail: "Inactivated rabies vaccine administered after the microchip. Entry is permitted only after a 21-day wait from the date of the primary vaccination.",
                      leadTimeDays: -22, citation: "EU pet travel scheme",
                      citationURL: aphisEU),
                .init(id: "ehc", title: "EU Health Cert + APHIS endorsement",
                      detail: "EU Annex IV health certificate, issued by a USDA-accredited vet and APHIS-endorsed within 10 days of entry into Ireland.",
                      leadTimeDays: -10, citation: "APHIS EU",
                      citationURL: aphisEU),
                .init(id: "tapeworm", title: "Tapeworm treatment (dogs)", detail: "24–120h before arrival.", leadTimeDays: -2, citation: "DAFM", citationURL: dafmIreland)
            ]),
        Destination(
            id: "CHE", name: "Switzerland", flag: "🇨🇭",
            requiresFreeTier: false, rulesUpdated: date("2026-01-20"),
            steps: [
                .init(id: "microchip", title: "ISO microchip before vaccine",
                      detail: "ISO 11784/11785 compliant chip implanted BEFORE the rabies vaccine. Switzerland follows the EU pet travel scheme rules even though it isn't an EU member — BLV inspects at Zurich and Geneva.",
                      leadTimeDays: -60, citation: "BLV",
                      citationURL: blvSwitzerland),
                .init(id: "rabies", title: "Rabies + 21-day wait",
                      detail: "Inactivated rabies vaccine administered after the microchip. A 21-day wait from the date of primary vaccination is required before entry.",
                      leadTimeDays: -22, citation: "BLV",
                      citationURL: blvSwitzerland),
                .init(id: "ehc", title: "USDA-endorsed Swiss health cert",
                      detail: "EU-style health certificate for Switzerland, issued by a USDA-accredited vet and APHIS-endorsed within 10 days of entry.",
                      leadTimeDays: -10, citation: "APHIS Switzerland",
                      citationURL: aphisSwitzerland)
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
