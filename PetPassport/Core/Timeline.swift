import Foundation

/// A single concrete action the owner needs to take, rendered in date-sorted
/// order on the timeline screen.
struct TimelineItem: Identifiable, Hashable {
    let id: String
    let dueBy: Date
    let title: String
    let detail: String
    let citation: String?
    let citationURL: URL?
    let isPast: Bool

    init(id: String,
         dueBy: Date,
         title: String,
         detail: String,
         citation: String?,
         citationURL: URL? = nil,
         isPast: Bool) {
        self.id = id
        self.dueBy = dueBy
        self.title = title
        self.detail = detail
        self.citation = citation
        self.citationURL = citationURL
        self.isPast = isPast
    }
}

/// Pure-logic timeline builder. All policy lives in `Destination` — this
/// module just maps lead-times to absolute dates relative to a departure.
enum TimelineBuilder {
    /// Build a chronological timeline for `pet` travelling to `destination`
    /// on `departure`. `now` is injected so tests can pin "today".
    static func build(
        destination: Destination,
        pet: PetProfile,
        departure: Date,
        now: Date = Date()
    ) -> [TimelineItem] {
        let cal = Calendar(identifier: .gregorian)
        let items: [TimelineItem] = destination.steps.map { step in
            // leadTimeDays is negative = days BEFORE departure.
            let due = cal.date(byAdding: .day, value: step.leadTimeDays, to: departure) ?? departure
            return TimelineItem(
                id: "\(destination.id)-\(step.id)",
                dueBy: due,
                title: step.title,
                detail: filledDetail(step: step, pet: pet),
                citation: step.citation,
                citationURL: step.citationURL,
                isPast: due < now
            )
        }
        return items.sorted { $0.dueBy < $1.dueBy }
    }

    /// Lightweight feasibility check: does the departure date give enough
    /// lead-time for the longest required step? If not, we surface a warning
    /// on the UI so the user doesn't plan an impossible trip.
    static func earliestPossibleDeparture(from today: Date, for destination: Destination) -> Date? {
        let cal = Calendar(identifier: .gregorian)
        // Worst lead-time is the MOST negative step; flip sign to get positive "days needed".
        let daysNeeded = destination.steps.map { -$0.leadTimeDays }.max() ?? 0
        return cal.date(byAdding: .day, value: daysNeeded, to: today)
    }

    /// Substitute pet attributes into the step detail so e.g. dog-only rules
    /// only mention dogs when the current pet IS a dog.
    private static func filledDetail(step: ComplianceStep, pet: PetProfile) -> String {
        let isDogsOnly = step.title.contains("(dogs only)") || step.detail.contains("(dogs only)")
        if isDogsOnly && pet.species != .dog {
            return step.detail + "  — Not applicable for \(pet.species.label.lowercased())s."
        }
        return step.detail
    }
}
