import Foundation
import WattcherCore

@MainActor
final class AuditScheduler {
    private var activity: NSBackgroundActivityScheduler?

    func schedule(
        interval: MonitorInterval,
        handler: @escaping @MainActor () async -> Void
    ) {
        activity?.invalidate()
        let scheduler = NSBackgroundActivityScheduler(identifier: "app.wattcher.audit")
        scheduler.interval = TimeInterval(interval.rawValue)
        scheduler.tolerance = min(900, max(60, scheduler.interval * 0.1))
        scheduler.repeats = true
        scheduler.qualityOfService = .utility
        scheduler.schedule { completion in
            Task { @MainActor in
                await handler()
                completion(.finished)
            }
        }
        activity = scheduler
    }

    func stop() {
        activity?.invalidate()
        activity = nil
    }
}
