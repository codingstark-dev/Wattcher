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
    var errorMessage: String?
}

@MainActor
struct MenuActions {
    let checkNow: () -> Void
    let selectInterval: (MonitorInterval) -> Void
    let reviewFinding: (String) -> Void
    let reviewPortOwner: (String) -> Void
    let toggleLaunchAtLogin: () -> Void
    let resetIgnoredProcesses: () -> Void
    let quit: () -> Void
}
