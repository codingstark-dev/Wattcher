import Foundation

@MainActor
public final class StateStore {
    private enum Key {
        static let state = "monitorState"
        static let interval = "monitorInterval"
        static let notifications = "lastNotificationDates"
        static let pendingFindings = "pendingFindings"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadState() -> MonitorState {
        guard let data = defaults.data(forKey: Key.state),
              let state = try? decoder.decode(MonitorState.self, from: data)
        else { return MonitorState() }
        return state
    }

    public func saveState(_ state: MonitorState) {
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: Key.state)
    }

    public var interval: MonitorInterval {
        get {
            MonitorInterval(rawValue: defaults.integer(forKey: Key.interval)) ?? .oneHour
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.interval)
        }
    }

    public func ignore(identity: String) {
        var state = loadState()
        if state.ignoredIdentityOrder.isEmpty {
            state.ignoredIdentityOrder = state.ignoredIdentities.sorted()
        }
        state.ignoredIdentities.insert(identity)
        state.ignoredIdentityOrder.removeAll { $0 == identity }
        state.ignoredIdentityOrder.append(identity)
        while state.ignoredIdentityOrder.count > 200 {
            state.ignoredIdentities.remove(state.ignoredIdentityOrder.removeFirst())
        }
        saveState(state)
    }

    public var ignoredCount: Int {
        loadState().ignoredIdentities.count
    }

    public func clearIgnoredIdentities() {
        var state = loadState()
        state.ignoredIdentities.removeAll()
        state.ignoredIdentityOrder.removeAll()
        saveState(state)
    }

    public func shouldNotify(key: String, now: Date, cooldown: TimeInterval) -> Bool {
        let dates = prunedNotificationDates(now: now)
        guard let lastDate = dates[key] else { return true }
        return now.timeIntervalSince(lastDate) >= cooldown
    }

    public func recordNotification(key: String, date: Date) {
        var dates = prunedNotificationDates(now: date)
        dates[key] = date
        if dates.count > 200 {
            dates = Dictionary(uniqueKeysWithValues: dates
                .sorted { $0.value > $1.value }
                .prefix(200)
                .map { ($0.key, $0.value) })
        }
        defaults.set(dates, forKey: Key.notifications)
    }

    public func loadPendingFindings(now: Date = Date()) -> [Finding] {
        let pending = loadPending().filter { now.timeIntervalSince($0.createdAt) < 86_400 }
        savePending(pending)
        return pending.sorted { $0.createdAt > $1.createdAt }.map(\.finding)
    }

    public func mergePendingFindings(_ findings: [Finding], at date: Date) -> [Finding] {
        var pendingByID = Dictionary(uniqueKeysWithValues: loadPending()
            .filter { date.timeIntervalSince($0.createdAt) < 86_400 }
            .map { ($0.finding.id, $0) })
        for finding in findings {
            pendingByID[finding.id] = PendingFinding(finding: finding, createdAt: date)
        }
        let pending = Array(pendingByID.values)
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(50)
        savePending(Array(pending))
        return pending.map(\.finding)
    }

    public func removePendingFinding(id: String) {
        savePending(loadPending().filter { $0.finding.id != id })
    }

    public func removePendingFindings(ignoreIdentity: String) {
        savePending(loadPending().filter {
            $0.finding.process.ignoreIdentity != ignoreIdentity
        })
    }

    private func prunedNotificationDates(now: Date) -> [String: Date] {
        let dates = defaults.dictionary(forKey: Key.notifications) as? [String: Date] ?? [:]
        return dates.filter { now.timeIntervalSince($0.value) < 604_800 }
    }

    private func loadPending() -> [PendingFinding] {
        guard let data = defaults.data(forKey: Key.pendingFindings),
              let pending = try? decoder.decode([PendingFinding].self, from: data)
        else { return [] }
        return pending
    }

    private func savePending(_ pending: [PendingFinding]) {
        guard let data = try? encoder.encode(pending) else { return }
        defaults.set(data, forKey: Key.pendingFindings)
    }
}
