import AppKit
import WattcherCore

@MainActor
final class OverviewViewController: NSViewController {
    private let actions: OverviewActions
    private let preferences: AppPreferences
    private let workspace = PortWorkspaceActions()
    private var state = MenuViewState()
    private var rows = [ProcessSample]()

    private let searchField = NSSearchField()
    private let showAllButton = NSButton(checkboxWithTitle: "Show all listeners", target: nil, action: nil)
    private let summaryLabel = NSTextField(labelWithString: "Battery and process summary loading…")
    private let statusLabel = NSTextField(labelWithString: "Waiting for first scan…")
    private let tableView = NSTableView()
    private let openButton = NSButton(title: "Open", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let terminalButton = NSButton(title: "Terminal", target: nil, action: nil)
    private let revealButton = NSButton(title: "Reveal", target: nil, action: nil)
    private let reviewButton = NSButton(title: "Review…", target: nil, action: nil)
    private let quitVisibleButton = NSButton(title: "Quit Visible…", target: nil, action: nil)

    init(actions: OverviewActions, preferences: AppPreferences) {
        self.actions = actions
        self.preferences = preferences
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSVisualEffectView()
        root.material = .underWindowBackground
        root.blendingMode = .behindWindow
        root.state = .active
        view = root
        configureTable()
        configureControls()
        layoutContent()
        updateSelection()
    }

    func render(_ state: MenuViewState) {
        self.state = state
        reloadRows()
    }

    func requestRefresh() {
        actions.refresh()
    }

    private func configureTable() {
        let columns: [(String, String, CGFloat)] = [
            ("port", "Port", 75),
            ("process", "Process", 210),
            ("cpu", "CPU", 60),
            ("memory", "Memory", 75),
            ("impact", "Impact", 80),
        ]
        for (id, title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = width
            column.minWidth = id == "process" ? 180 : 65
            tableView.addTableColumn(column)
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.style = .fullWidth
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 42
        tableView.doubleAction = #selector(reviewSelected)
        tableView.target = self
        tableView.setAccessibilityLabel("Listening port owners")
    }

    private func configureControls() {
        searchField.placeholderString = "Search port, process, path, or PID"
        searchField.delegate = self
        searchField.setAccessibilityLabel("Search listening ports")
        showAllButton.target = self
        showAllButton.action = #selector(toggleShowAll)
        showAllButton.state = preferences.showAllPorts ? .on : .off
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        summaryLabel.textColor = .secondaryLabelColor
        configure(openButton, action: #selector(openSelected), help: "Open the selected local port in your browser")
        configure(copyButton, action: #selector(copySelected), help: "Copy the selected listening endpoints")
        configure(terminalButton, action: #selector(openTerminal), help: "Open Terminal at the executable directory")
        configure(revealButton, action: #selector(revealSelected), help: "Reveal the executable in Finder")
        configure(reviewButton, action: #selector(reviewSelected), help: "Review details and optionally quit the selected process")
        configure(quitVisibleButton, action: #selector(quitVisible), help: "Review and quit every visible process")
    }

    private func configure(_ button: NSButton, action: Selector, help: String) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.setAccessibilityHelp(help)
    }

    private func layoutContent() {
        let icon = NSImageView(image: BrandAssets.applicationIcon)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let title = NSTextField(labelWithString: "Wattcher")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Processes, estimated battery impact, and listening ports")
        subtitle.textColor = .secondaryLabelColor
        let titles = NSStackView(views: [title, subtitle])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 2
        let header = NSStackView(views: [icon, titles])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        let filterRow = NSStackView(views: [searchField, showAllButton])
        filterRow.orientation = .horizontal
        filterRow.alignment = .centerY
        filterRow.spacing = 12
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        let actionRow = NSStackView(views: [
            openButton, copyButton, terminalButton, revealButton, reviewButton,
            NSView(), quitVisibleButton,
        ])
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 8
        let footer = NSStackView(views: [statusLabel, NSView(), footerButton("Refresh", #selector(refresh)), footerButton("Settings…", #selector(openSettings))])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8
        for child in [header, summaryLabel, filterRow, scroll, actionRow, footer] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 48), icon.heightAnchor.constraint(equalToConstant: 48),
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 24), header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            summaryLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10), summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            filterRow.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 14), filterRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), filterRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            scroll.topAnchor.constraint(equalTo: filterRow.bottomAnchor, constant: 12), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            actionRow.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12), actionRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), actionRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            footer.topAnchor.constraint(equalTo: actionRow.bottomAnchor, constant: 14), footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24), footer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
        ])
    }

    private func footerButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .inline
        return button
    }

    private func reloadRows() {
        rows = PortFilter.filtered(state.processes, query: searchField.stringValue, showAll: preferences.showAllPorts)
        tableView.reloadData()
        let stamp = state.lastCheck?.formatted(date: .omitted, time: .shortened) ?? "not yet"
        let battery = state.battery?.percentage.map { "\($0)%" } ?? "unknown"
        summaryLabel.stringValue = "Battery \(battery) · \(state.processes.count) processes · \(state.findings.count) findings · audits about every \(state.interval.title)"
        statusLabel.stringValue = "\(rows.count) visible · last checked \(stamp)"
        quitVisibleButton.isEnabled = !rows.isEmpty
        updateSelection()
    }

    private var selected: ProcessSample? {
        guard rows.indices.contains(tableView.selectedRow) else { return nil }
        return rows[tableView.selectedRow]
    }

    private func updateSelection() {
        let enabled = selected != nil
        [openButton, copyButton, terminalButton, revealButton, reviewButton].forEach { $0.isEnabled = enabled }
    }

    @objc private func toggleShowAll() { preferences.showAllPorts = showAllButton.state == .on; reloadRows() }
    @objc private func refresh() { actions.refresh() }
    @objc private func openSettings() { actions.openSettings() }
    @objc private func reviewSelected() { if let selected { actions.review(selected.identity) } }
    @objc private func copySelected() { if let selected { workspace.copyEndpoints(selected) } }
    @objc private func revealSelected() { if let selected { workspace.revealExecutable(selected) } }
    @objc private func quitVisible() { actions.quitVisible(rows.map(\.identity)) }

    @objc private func openSelected() {
        guard let selected else { return }
        workspace.open(selected)
        if preferences.closeAfterOpening { view.window?.close() }
    }

    @objc private func openTerminal() {
        guard let selected else { return }
        workspace.openTerminal(selected)
        if preferences.closeAfterOpening { view.window?.close() }
    }
}

extension OverviewViewController: NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let process = rows[row]
        let label = NSTextField(labelWithString: cellText(process, column: tableColumn.identifier.rawValue))
        label.lineBreakMode = .byTruncatingMiddle
        label.toolTip = tableColumn.identifier.rawValue == "port"
            ? process.ports.map(\.displayName).joined(separator: ", ")
            : process.executablePath
        if tableColumn.identifier.rawValue == "impact" { label.textColor = impactColor(process) }
        label.setAccessibilityLabel("\(tableColumn.title): \(label.stringValue)")
        return label
    }

    func tableViewSelectionDidChange(_ notification: Notification) { updateSelection() }
    func controlTextDidChange(_ obj: Notification) { reloadRows() }

    private func cellText(_ process: ProcessSample, column: String) -> String {
        switch column {
        case "port":
            guard let first = process.ports.first else { return "—" }
            return process.ports.count == 1
                ? String(first.port)
                : "\(first.port) +\(process.ports.count - 1)"
        case "process": return "\(process.name)  ·  PID \(process.pid)"
        case "cpu": return String(format: "%.1f%%", process.cpuPercent)
        case "memory": return String(format: "%.0f MB", process.residentMegabytes)
        case "impact": return process.cpuPercent >= 15 ? "High" : process.cpuPercent >= 5 ? "Medium" : "Low"
        default: return ""
        }
    }

    private func impactColor(_ process: ProcessSample) -> NSColor {
        process.cpuPercent >= 15 ? .systemRed : process.cpuPercent >= 5 ? .systemOrange : .systemGreen
    }
}
