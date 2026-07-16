import AppKit
import WattcherCore

@MainActor
struct SettingsActions {
    let setInterval: (MonitorInterval) -> Void
    let toggleLaunchAtLogin: () -> Void
    let shortcutChanged: () -> Void
    let updatesChanged: () -> Void
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    private let actions: SettingsActions
    private let preferences: AppPreferences
    private let updates: UpdateController
    private var state = MenuViewState()
    private let intervalPopup = NSPopUpButton()
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Launch Wattcher at login", target: nil, action: nil)
    private let liveRefreshPopup = NSPopUpButton()
    private let closeAfterOpenButton = NSButton(checkboxWithTitle: "Close Overview after opening a port or Terminal", target: nil, action: nil)
    private let shortcutEnabledButton = NSButton(checkboxWithTitle: "Enable a global shortcut", target: nil, action: nil)
    private let shortcutPopup = NSPopUpButton()
    private let shortcutStatusLabel = NSTextField(labelWithString: "Global shortcut is off")
    private let automaticChecksButton = NSButton(checkboxWithTitle: "Automatically check for updates", target: nil, action: nil)
    private let automaticDownloadsButton = NSButton(checkboxWithTitle: "Download and install updates automatically", target: nil, action: nil)

    init(actions: SettingsActions, preferences: AppPreferences, updates: UpdateController) {
        self.actions = actions
        self.preferences = preferences
        self.updates = updates
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 610),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Wattcher Settings"
        window.titlebarAppearsTransparent = true
        super.init(window: window)
        window.contentView = buildContent()
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        showWindow(nil)
        window?.center()
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func render(_ state: MenuViewState) {
        self.state = state
        intervalPopup.selectItem(withTag: state.interval.rawValue)
        launchAtLoginButton.state = state.launchAtLogin ? .on : .off
        automaticChecksButton.state = updates.automaticallyChecks ? .on : .off
        automaticDownloadsButton.state = updates.automaticallyDownloads ? .on : .off
        automaticDownloadsButton.isEnabled = updates.automaticallyChecks
        shortcutEnabledButton.state = preferences.globalShortcutEnabled ? .on : .off
        shortcutPopup.selectItem(withTag: GlobalShortcut.allCases.firstIndex(of: preferences.globalShortcut) ?? 0)
        shortcutPopup.isEnabled = preferences.globalShortcutEnabled
        shortcutStatusLabel.stringValue = state.shortcutStatus
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    private func buildContent() -> NSView {
        let root = NSVisualEffectView()
        root.material = .underWindowBackground
        root.blendingMode = .behindWindow
        root.state = .active
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 18
        content.edgeInsets = NSEdgeInsets(top: 26, left: 28, bottom: 24, right: 28)
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: root.topAnchor), content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor), content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        content.addArrangedSubview(brandHeader())
        content.addArrangedSubview(section("Monitoring", views: monitoringControls()))
        content.addArrangedSubview(section("Overview", views: overviewControls()))
        content.addArrangedSubview(section("Keyboard Shortcut", views: shortcutControls()))
        content.addArrangedSubview(section("Updates", views: updateControls()))
        content.addArrangedSubview(aboutRow())
        return root
    }

    private func brandHeader() -> NSView {
        let icon = NSImageView(image: BrandAssets.applicationIcon)
        icon.imageScaling = .scaleProportionallyUpOrDown
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 64), icon.heightAnchor.constraint(equalToConstant: 64)])
        let title = NSTextField(labelWithString: "Wattcher")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let detail = NSTextField(labelWithString: "Version \(version) · Open source by codingstark-dev")
        detail.textColor = .secondaryLabelColor
        let text = NSStackView(views: [title, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3
        let row = NSStackView(views: [icon, text])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        return row
    }

    private func monitoringControls() -> [NSView] {
        intervalPopup.removeAllItems()
        for interval in MonitorInterval.allCases {
            intervalPopup.addItem(withTitle: interval.title)
            intervalPopup.lastItem?.tag = interval.rawValue
        }
        intervalPopup.target = self
        intervalPopup.action = #selector(changeInterval)
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(toggleLaunchAtLogin)
        let row = labeled("Scheduled audit", control: intervalPopup)
        return [row, launchAtLoginButton]
    }

    private func overviewControls() -> [NSView] {
        for seconds in [5, 10, 30, 60] {
            liveRefreshPopup.addItem(withTitle: "Every \(seconds) seconds")
            liveRefreshPopup.lastItem?.tag = seconds
        }
        liveRefreshPopup.selectItem(withTag: Int(preferences.liveRefreshInterval))
        liveRefreshPopup.target = self
        liveRefreshPopup.action = #selector(changeLiveRefresh)
        closeAfterOpenButton.state = preferences.closeAfterOpening ? .on : .off
        closeAfterOpenButton.target = self
        closeAfterOpenButton.action = #selector(toggleCloseAfterOpen)
        return [labeled("Live refresh while open", control: liveRefreshPopup), closeAfterOpenButton]
    }

    private func shortcutControls() -> [NSView] {
        shortcutEnabledButton.target = self
        shortcutEnabledButton.action = #selector(toggleShortcut)
        shortcutPopup.removeAllItems()
        for (index, shortcut) in GlobalShortcut.allCases.enumerated() {
            shortcutPopup.addItem(withTitle: shortcut.title)
            shortcutPopup.lastItem?.tag = index
        }
        shortcutPopup.target = self
        shortcutPopup.action = #selector(changeShortcut)
        shortcutStatusLabel.textColor = .secondaryLabelColor
        shortcutStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        return [labeled("Open Overview anywhere", control: shortcutPopup), shortcutEnabledButton, shortcutStatusLabel]
    }

    private func updateControls() -> [NSView] {
        automaticChecksButton.target = self
        automaticChecksButton.action = #selector(toggleAutomaticChecks)
        automaticDownloadsButton.target = self
        automaticDownloadsButton.action = #selector(toggleAutomaticDownloads)
        let checkButton = NSButton(title: "Check for Updates…", target: self, action: #selector(checkForUpdates))
        return [automaticChecksButton, automaticDownloadsButton, checkButton]
    }

    private func section(_ title: String, views: [NSView]) -> NSView {
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        let separator = NSBox()
        separator.boxType = .separator
        let stack = NSStackView(views: [heading] + views + [separator])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.widthAnchor.constraint(equalToConstant: 464).isActive = true
        separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func labeled(_ title: String, control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 190).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func aboutRow() -> NSView {
        let source = NSButton(title: "View Source Code", target: self, action: #selector(openSource))
        source.bezelStyle = .inline
        let privacy = NSTextField(labelWithString: "All process and port telemetry stays on this Mac.")
        privacy.textColor = .secondaryLabelColor
        let row = NSStackView(views: [privacy, NSView(), source])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 464).isActive = true
        return row
    }

    @objc private func changeInterval() {
        if let interval = MonitorInterval(rawValue: intervalPopup.selectedTag()) { actions.setInterval(interval) }
    }

    @objc private func toggleLaunchAtLogin() { actions.toggleLaunchAtLogin() }
    @objc private func changeLiveRefresh() { preferences.liveRefreshInterval = TimeInterval(liveRefreshPopup.selectedTag()) }
    @objc private func toggleCloseAfterOpen() { preferences.closeAfterOpening = closeAfterOpenButton.state == .on }

    @objc private func toggleShortcut() {
        preferences.globalShortcutEnabled = shortcutEnabledButton.state == .on
        shortcutPopup.isEnabled = preferences.globalShortcutEnabled
        actions.shortcutChanged()
    }

    @objc private func changeShortcut() {
        let index = shortcutPopup.selectedTag()
        guard GlobalShortcut.allCases.indices.contains(index) else { return }
        preferences.globalShortcut = GlobalShortcut.allCases[index]
        actions.shortcutChanged()
    }

    @objc private func toggleAutomaticChecks() {
        updates.automaticallyChecks = automaticChecksButton.state == .on
        automaticDownloadsButton.isEnabled = updates.automaticallyChecks
        actions.updatesChanged()
    }

    @objc private func toggleAutomaticDownloads() {
        updates.automaticallyDownloads = automaticDownloadsButton.state == .on
        actions.updatesChanged()
    }

    @objc private func checkForUpdates() { updates.checkForUpdates() }

    @objc private func openSource() {
        NSWorkspace.shared.open(URL(string: "https://github.com/codingstark-dev/Wattcher")!)
    }
}
