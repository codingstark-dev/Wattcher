import AppKit
import UserNotifications
import WattcherCore

@MainActor
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private enum Action {
        static let review = "WATTCHER_REVIEW"
        static let ignore = "WATTCHER_IGNORE"
        static let category = "WATTCHER_FINDING"
    }

    private let center = UNUserNotificationCenter.current()
    var onReview: ((String) -> Void)?
    var onIgnore: ((String) -> Void)?

    func configure() {
        center.delegate = self
        let review = UNNotificationAction(
            identifier: Action.review,
            title: "Review",
            options: [.foreground]
        )
        let ignore = UNNotificationAction(
            identifier: Action.ignore,
            title: "Ignore Future Alerts",
            options: [.foreground]
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Action.category,
                actions: [review, ignore],
                intentIdentifiers: [],
                options: []
            ),
        ])
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func post(_ findings: [Finding]) {
        guard let first = findings.first else { return }
        let content = UNMutableNotificationContent()
        content.title = findings.count == 1
            ? "Wattcher found activity to review"
            : "Wattcher found \(findings.count) items to review"
        content.body = "Open Wattcher to see the process, RAM, port, and estimated-impact evidence."
        content.sound = .default
        content.categoryIdentifier = Action.category
        content.userInfo = ["findingID": first.id]
        let request = UNNotificationRequest(
            identifier: first.id,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func remove(id: String) {
        center.removeDeliveredNotifications(withIdentifiers: [id])
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let id = response.notification.request.content.userInfo["findingID"] as? String else {
            return
        }
        let action = response.actionIdentifier
        await MainActor.run { [weak self] in
            guard let self else { return }
            if action == Action.ignore {
                onIgnore?(id)
            } else {
                NSApplication.shared.activate(ignoringOtherApps: true)
                onReview?(id)
            }
        }
    }
}
