import Foundation
import WattcherCore

@MainActor
struct MenuViewState {
    var isScanning = false
    var lastCheck: Date?
    var nextCheck: Date?
    var battery: BatteryState?
    var findings = [Finding]()
    var processes = [ProcessSample]()
    var interval = MonitorInterval.oneHour
    var launchAtLogin = false
    var ignoredCount = 0
    var automaticallyChecksForUpdates = true
    var automaticallyDownloadsUpdates = true
    var shortcutStatus = "Global shortcut is off"
    var errorMessage: String?
}

@MainActor
struct MenuActions {
    let openOverview: () -> Void
    let openSettings: () -> Void
    let checkNow: () -> Void
    let checkForUpdates: () -> Void
    let selectInterval: (MonitorInterval) -> Void
    let reviewFinding: (String) -> Void
    let reviewPortOwner: (String) -> Void
    let toggleLaunchAtLogin: () -> Void
    let resetIgnoredProcesses: () -> Void
    let quit: () -> Void
}
