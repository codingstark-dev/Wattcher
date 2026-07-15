import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: MonitorCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let coordinator = MonitorCoordinator()
        self.coordinator = coordinator
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}
