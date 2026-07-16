import AppKit
import WattcherCore

@MainActor
final class MenuController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let actions: MenuActions
    private var state = MenuViewState()

    init(actions: MenuActions) {
        self.actions = actions
        super.init()
        statusItem.button?.image = BrandAssets.statusIcon
        statusItem.button?.toolTip = "Wattcher"
        rebuildMenu()
    }

    func render(_ state: MenuViewState) {
        self.state = state
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let titleItem = label("Wattcher", bold: true)
        titleItem.image = BrandAssets.applicationIcon
        titleItem.image?.size = NSSize(width: 18, height: 18)
        menu.addItem(titleItem)
        menu.addItem(label(statusText))
        menu.addItem(label(batteryText))
        menu.addItem(label(scheduleText))
        menu.addItem(.separator())
        let overviewItem = NSMenuItem(
            title: "Open Overview…",
            action: #selector(openOverview),
            keyEquivalent: ""
        )
        overviewItem.target = self
        overviewItem.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: nil)
        menu.addItem(overviewItem)
        menu.addItem(listenersMenu())
        menu.addItem(activityMenu())

        if let error = state.errorMessage {
            menu.addItem(.separator())
            menu.addItem(label("Error: \(error)"))
        }

        menu.addItem(.separator())
        if state.findings.isEmpty {
            menu.addItem(label(state.lastCheck == nil ? "No scan yet" : "No current findings"))
        } else {
            let findingsItem = NSMenuItem(title: "Findings (\(state.findings.count))", action: nil, keyEquivalent: "")
            let findingsMenu = NSMenu()
            for finding in state.findings {
                let item = NSMenuItem(
                    title: finding.title,
                    action: #selector(reviewFinding(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = finding.id
                item.toolTip = finding.evidence
                findingsMenu.addItem(item)
            }
            findingsItem.submenu = findingsMenu
            menu.addItem(findingsItem)
        }

        menu.addItem(.separator())
        let checkItem = NSMenuItem(
            title: state.isScanning ? "Checking…" : "Check Now",
            action: #selector(checkNow),
            keyEquivalent: "r"
        )
        checkItem.target = self
        checkItem.isEnabled = !state.isScanning
        menu.addItem(checkItem)
        menu.addItem(intervalMenu())

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = state.launchAtLogin ? .on : .off
        menu.addItem(loginItem)
        if state.ignoredCount > 0 {
            let resetItem = NSMenuItem(
                title: "Reset Ignored Processes (\(state.ignoredCount))…",
                action: #selector(resetIgnoredProcesses),
                keyEquivalent: ""
            )
            resetItem.target = self
            menu.addItem(resetItem)
        }

        menu.addItem(.separator())
        let updateMode = state.automaticallyChecksForUpdates
            ? (state.automaticallyDownloadsUpdates ? "Automatic updates: On" : "Automatic update checks: On")
            : "Automatic updates: Off"
        menu.addItem(label(updateMode))
        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        let quitItem = NSMenuItem(title: "Quit Wattcher", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func intervalMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Check interval: \(state.interval.title)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for interval in MonitorInterval.allCases {
            let item = NSMenuItem(
                title: interval.title,
                action: #selector(selectInterval(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = interval.rawValue
            item.state = interval == state.interval ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func listenersMenu() -> NSMenuItem {
        let listeners = state.processes
            .filter { !$0.ports.isEmpty }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let parent = NSMenuItem(
            title: "Port owners (\(listeners.count))",
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        if listeners.isEmpty {
            submenu.addItem(label("No listening ports"))
        } else {
            for process in listeners.prefix(30) {
                let ports = process.ports.map(\.displayName).joined(separator: ", ")
                let item = NSMenuItem(
                    title: String(
                    format: "%@ · %.0f MB · %@",
                    process.name,
                    process.residentMegabytes,
                    ports
                    ),
                    action: #selector(reviewPortOwner(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = process.identity
                item.toolTip = String(
                    format: "%.1f%% CPU · %@ · %@",
                    process.cpuPercent,
                    process.origin.label,
                    process.executablePath
                )
                submenu.addItem(item)
            }
        }
        parent.submenu = submenu
        return parent
    }

    private func activityMenu() -> NSMenuItem {
        let active = state.processes
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(10)
        let parent = NSMenuItem(title: "Top CPU activity · last scan", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for process in active {
            submenu.addItem(label(String(
                format: "%@ · %.1f%% CPU · %.0f MB",
                process.name,
                process.cpuPercent,
                process.residentMegabytes
            )))
        }
        parent.submenu = submenu
        return parent
    }

    private func label(_ text: String, bold: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = true
        item.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .font: bold
                    ? NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
                    : NSFont.menuFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: bold ? NSColor.labelColor : NSColor.secondaryLabelColor,
            ]
        )
        return item
    }

    private var statusText: String {
        if state.isScanning { return "Scanning processes and listening ports…" }
        guard let date = state.lastCheck else { return "Last check: never" }
        return "Last check: \(date.formatted(date: .omitted, time: .shortened))"
    }

    private var batteryText: String {
        guard let battery = state.battery else { return "Battery: waiting for first scan" }
        let percentage = battery.percentage.map { "\($0)%" } ?? "Unknown"
        return "Battery: \(percentage) · \(battery.source)"
    }

    private var scheduleText: String {
        guard let date = state.nextCheck else { return "Checks about every \(state.interval.title)" }
        return "Next check around \(date.formatted(date: .omitted, time: .shortened))"
    }

    @objc private func checkNow() { actions.checkNow() }
    @objc private func openOverview() { actions.openOverview() }
    @objc private func openSettings() { actions.openSettings() }
    @objc private func checkForUpdates() { actions.checkForUpdates() }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? Int,
              let interval = MonitorInterval(rawValue: rawValue)
        else { return }
        actions.selectInterval(interval)
    }

    @objc private func reviewFinding(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        actions.reviewFinding(id)
    }

    @objc private func reviewPortOwner(_ sender: NSMenuItem) {
        guard let identity = sender.representedObject as? String else { return }
        actions.reviewPortOwner(identity)
    }

    @objc private func toggleLaunchAtLogin() { actions.toggleLaunchAtLogin() }
    @objc private func resetIgnoredProcesses() { actions.resetIgnoredProcesses() }
    @objc private func quit() { actions.quit() }
}
