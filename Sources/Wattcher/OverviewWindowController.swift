import AppKit
import WattcherCore

@MainActor
struct OverviewActions {
    let refresh: () -> Void
    let review: (String) -> Void
    let quitVisible: ([String]) -> Void
    let openSettings: () -> Void
}

@MainActor
final class OverviewWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    private let contentController: OverviewViewController
    private let preferences: AppPreferences
    private var refreshTimer: Timer?

    init(actions: OverviewActions, preferences: AppPreferences) {
        self.preferences = preferences
        contentController = OverviewViewController(actions: actions, preferences: preferences)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Wattcher Overview"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 640, height: 420)
        window.contentViewController = contentController
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        showWindow(nil)
        window?.center()
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        startRefreshTimer()
    }

    func render(_ state: MenuViewState) {
        contentController.render(state)
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
        onClose?()
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: preferences.liveRefreshInterval,
            repeats: true
        ) { [weak contentController] _ in
            MainActor.assumeIsolated { contentController?.requestRefresh() }
        }
    }
}
