import Foundation
import UserNotifications

/// Pure-compute + impure-schedule split for travel-deadline reminders.
///
/// The compute side (`plan(items:tripKey:offsets:now:)`) is deterministic
/// and unit-testable — it takes a list of `TimelineItem`s and emits the
/// list of `PlannedReminder`s that *should* exist for that trip right now.
///
/// The impure side (`apply(plan:tripKey:trip:)`, `cancelAll(for:)`,
/// `cancelEverything()`) talks to `UNUserNotificationCenter`. It's
/// idempotent — re-running on departure-date change, destination change,
/// or settings-toggle is always safe.
///
/// Permission is requested **only** when there's actual work to schedule
/// (i.e. `plan.toCreate` is non-empty AND the user has the master toggle
/// on). Cold launch never triggers a permission prompt — pre-empts
/// 5.1.1(i).
struct ReminderScheduler {

    // MARK: - Public types

    /// One concrete fire-time for one timeline item. The identifier is
    /// stable (deterministic) so re-running `plan` produces the same id
    /// for the same trip+item+offset, which is what makes the reconcile
    /// idempotent.
    struct PlannedReminder: Hashable {
        let identifier: String
        let itemId: String
        let title: String
        let body: String
        let fireAt: Date
        let daysBefore: Int
    }

    /// The diff between "what should be scheduled" and "what's currently
    /// scheduled". Pure-data; the apply step turns it into UN calls.
    struct Plan: Equatable {
        /// Reminders that need to be added (not yet in the system).
        let toCreate: [PlannedReminder]
        /// Identifiers of pending requests that should be cancelled (the
        /// underlying TimelineItem moved, was removed, or the offset is no
        /// longer applicable e.g. the date is in the past).
        let toCancel: [String]
    }

    /// "Trip key" — used to namespace reminder identifiers so reminders
    /// for one pet/destination can be reconciled without disturbing
    /// reminders for another pet/destination. Stable across departure-date
    /// changes (so we cancel + reschedule cleanly).
    struct TripKey: Hashable {
        let petId: UUID
        let destinationId: String

        /// Identifier prefix used for every reminder belonging to this
        /// trip. `cancelAll(for:)` filters pending requests by this prefix.
        var identifierPrefix: String {
            "petpassport.reminder.\(petId.uuidString).\(destinationId)."
        }
    }

    /// Days-before-due offsets we fire reminders at. `0` means the day-of.
    /// 5 timeline items × 4 offsets = up to 20 reminders per trip — well
    /// inside the 64 pending-request budget iOS gives an app.
    static let standardOffsets: [Int] = [30, 7, 1, 0]

    // MARK: - Pure compute

    /// Given a list of timeline items + the requests already pending on
    /// the system, return the diff. Caller passes `existingIdentifiers`
    /// from `pendingNotificationRequests`; everything is deterministic
    /// from there.
    ///
    /// Filtering rules:
    /// - skip any (item, offset) whose computed fire date is in the past
    ///   relative to `now` — UNCalendarNotificationTrigger silently
    ///   discards those, but we'd rather not enqueue them in the first
    ///   place.
    /// - skip duplicates (same identifier already pending → not in
    ///   `toCreate`, but we DO keep it scheduled).
    /// - any pending identifier with the trip's prefix that isn't in the
    ///   "should-exist" set lands in `toCancel`.
    static func plan(items: [TimelineItem],
                     tripKey: TripKey,
                     existingIdentifiers: Set<String> = [],
                     offsets: [Int] = standardOffsets,
                     now: Date = Date()) -> Plan {
        let cal = Calendar(identifier: .gregorian)
        var desired: [PlannedReminder] = []
        var desiredIds = Set<String>()

        for item in items {
            for offset in offsets {
                guard let fire = cal.date(byAdding: .day, value: -offset, to: item.dueBy) else { continue }
                // Don't schedule reminders whose fire-time is already past.
                if fire <= now { continue }

                let id = identifier(tripKey: tripKey, itemId: item.id, daysBefore: offset)
                let title = makeTitle(daysBefore: offset, item: item)
                let body = makeBody(item: item)
                let r = PlannedReminder(identifier: id,
                                        itemId: item.id,
                                        title: title,
                                        body: body,
                                        fireAt: fire,
                                        daysBefore: offset)
                desired.append(r)
                desiredIds.insert(id)
            }
        }

        // Anything currently pending under this trip's prefix that isn't in
        // the desired set should be cancelled.
        let tripScoped = existingIdentifiers.filter { $0.hasPrefix(tripKey.identifierPrefix) }
        let toCancel = tripScoped.subtracting(desiredIds)

        // Things to create are "desired but not currently pending".
        let toCreate = desired.filter { !existingIdentifiers.contains($0.identifier) }

        return Plan(toCreate: toCreate, toCancel: Array(toCancel))
    }

    static func identifier(tripKey: TripKey, itemId: String, daysBefore: Int) -> String {
        "\(tripKey.identifierPrefix)\(itemId).d\(daysBefore)"
    }

    private static func makeTitle(daysBefore: Int, item: TimelineItem) -> String {
        switch daysBefore {
        case 0: return "Due today: \(item.title)"
        case 1: return "Due tomorrow: \(item.title)"
        default:
            return "In \(daysBefore) days: \(item.title)"
        }
    }

    private static func makeBody(item: TimelineItem) -> String {
        item.detail
    }

    // MARK: - Impure schedule

    /// Reconcile a trip's reminders against the system. Idempotent.
    /// Returns the number of reminders currently scheduled for the trip
    /// after the reconcile (used by Settings to surface a count).
    ///
    /// - Parameters:
    ///   - items: the timeline items for this trip (post-build).
    ///   - tripKey: pet + destination namespace.
    ///   - center: notification center (overridable for tests).
    ///   - permissionRequester: closure that returns whether the app has
    ///     permission. Defaults to the standard
    ///     `UNUserNotificationCenter.requestAuthorization` flow.
    @discardableResult
    static func apply(items: [TimelineItem],
                      tripKey: TripKey,
                      now: Date = Date(),
                      center: UNUserNotificationCenter = .current(),
                      permissionRequester: @Sendable () async -> Bool = ReminderScheduler.requestPermissionIfNeeded
    ) async -> Int {
        let pending = await center.pendingNotificationRequests()
        let existingIds = Set(pending.map(\.identifier))
        let p = plan(items: items, tripKey: tripKey, existingIdentifiers: existingIds, now: now)

        // Cancellations don't need permission — handle them first.
        if !p.toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: p.toCancel)
        }

        // Don't request permission if there's nothing to add.
        guard !p.toCreate.isEmpty else {
            return await pendingCount(for: tripKey, center: center)
        }

        // This is the moment of finalization — request permission now.
        let granted = await permissionRequester()
        if !granted { return await pendingCount(for: tripKey, center: center) }

        for reminder in p.toCreate {
            let req = makeRequest(for: reminder)
            try? await center.add(req)
        }
        return await pendingCount(for: tripKey, center: center)
    }

    /// Cancel every reminder belonging to a single trip.
    static func cancelAll(for tripKey: TripKey,
                          center: UNUserNotificationCenter = .current()) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(tripKey.identifierPrefix) }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Cancel every reminder this app has scheduled. Called when the user
    /// flips the master Settings toggle off.
    static func cancelEverything(center: UNUserNotificationCenter = .current()) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("petpassport.reminder.") }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Count of currently-pending reminders for a single trip.
    static func pendingCount(for tripKey: TripKey,
                             center: UNUserNotificationCenter = .current()) async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.filter { $0.identifier.hasPrefix(tripKey.identifierPrefix) }.count
    }

    /// Lazy authorization. Returns true if already granted (or
    /// provisionally granted). Returns false if denied. If the system has
    /// never asked, prompts now — this is the deliberate "request only at
    /// finalization" point.
    static func requestPermissionIfNeeded(center: UNUserNotificationCenter = .current()) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    /// Default-arg-friendly wrapper so the `permissionRequester:` closure
    /// in `apply` has a non-isolated entry point.
    @Sendable
    static func requestPermissionIfNeeded() async -> Bool {
        await requestPermissionIfNeeded(center: .current())
    }

    /// `true` if the system has been asked and the answer was "no". Used
    /// by the UI to decide whether to surface a "open Settings" hint.
    static func isDenied(center: UNUserNotificationCenter = .current()) async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .denied
    }

    private static func makeRequest(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.threadIdentifier = "petpassport.timeline"

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.fireAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier,
                                     content: content,
                                     trigger: trigger)
    }
}
