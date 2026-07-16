import AppKit
import Darwin
import ServiceManagement
import WattcherCore

@MainActor
final class MonitorCoordinator {
    private let scanner = SystemScanner()
    private let rules = RulesEngine()
    private let store = StateStore()
    private let scheduler = AuditScheduler()
    private let notifications = NotificationCoordinator()
    private let terminator = ProcessTerminator()
    private let reviewPresenter = ReviewPresenter()
    private let preferences = AppPreferences()
    private let updates = UpdateController()
    private let hotKey = GlobalHotKeyController()
    private var scanGate = ScanGate()
    private var menuState = MenuViewState()
    private var findingsByID = [String: Finding]()
    private var processesByIdentity = [String: ProcessSample]()
    private var overview: OverviewWindowController?
    private var settings: SettingsWindowController?

    private lazy var menu = MenuController(
        actions: MenuActions(
            openOverview: { [weak self] in self?.showOverview() },
            openSettings: { [weak self] in self?.showSettings() },
            checkNow: { [weak self] in self?.requestScan() },
            checkForUpdates: { [weak self] in self?.updates.checkForUpdates() },
            selectInterval: { [weak self] in self?.setInterval($0) },
            reviewFinding: { [weak self] in self?.reviewFinding(id: $0) },
            reviewPortOwner: { [weak self] in self?.reviewPortOwner(identity: $0) },
            toggleLaunchAtLogin: { [weak self] in self?.toggleLaunchAtLogin() },
            resetIgnoredProcesses: { [weak self] in self?.resetIgnoredProcesses() },
            quit: { NSApplication.shared.terminate(nil) }
        )
    )

    func start() {
        menuState.interval = store.interval
        menuState.launchAtLogin = SMAppService.mainApp.status == .enabled
        menuState.ignoredCount = store.ignoredCount
        menuState.automaticallyChecksForUpdates = updates.automaticallyChecks
        menuState.automaticallyDownloadsUpdates = updates.automaticallyDownloads
        menuState.findings = store.loadPendingFindings()
        findingsByID = Dictionary(uniqueKeysWithValues: menuState.findings.map { ($0.id, $0) })
        notifications.onReview = { [weak self] in self?.reviewFinding(id: $0) }
        notifications.onIgnore = { [weak self] in self?.requestIgnoreFinding(id: $0) }
        notifications.configure()
        hotKey.onInvoke = { [weak self] in self?.showOverview() }
        configureGlobalShortcut()
        scheduleNextAudit()
        renderAll()
        requestScan()
    }

    func stop() {
        scheduler.stop()
        hotKey.stop()
    }

    private func requestScan() {
        Task { await runScanIfIdle(rescheduleAfterScan: true) }
    }

    private func runScanIfIdle(rescheduleAfterScan: Bool) async {
        guard scanGate.begin() else { return }
        menuState.isScanning = true
        menuState.errorMessage = nil
        renderAll()
        defer {
            scanGate.end()
            menuState.isScanning = false
            if rescheduleAfterScan {
                scheduleNextAudit()
            } else {
                menuState.nextCheck = Date().addingTimeInterval(
                    TimeInterval(menuState.interval.rawValue)
                )
            }
            renderAll()
        }
        do {
            let snapshot = try await scanner.scan()
            let evaluation = rules.evaluate(
                samples: snapshot.processes,
                state: store.loadState(),
                currentUserID: getuid(),
                currentProcessID: getpid(),
                capturedAt: snapshot.capturedAt
            )
            store.saveState(evaluation.state)
            menuState.findings = store.mergePendingFindings(
                evaluation.findings,
                at: snapshot.capturedAt
            )
            findingsByID = Dictionary(uniqueKeysWithValues: menuState.findings.map { ($0.id, $0) })
            menuState.battery = snapshot.battery
            menuState.processes = snapshot.processes
            processesByIdentity = Dictionary(
                uniqueKeysWithValues: snapshot.processes.map { ($0.identity, $0) }
            )
            menuState.lastCheck = snapshot.capturedAt
            notifyNewFindings(evaluation.findings, at: snapshot.capturedAt)
        } catch {
            menuState.errorMessage = error.localizedDescription
        }
    }

    private func scheduleNextAudit() {
        scheduler.schedule(interval: menuState.interval) { [weak self] in
            await self?.runScanIfIdle(rescheduleAfterScan: false)
        }
        menuState.nextCheck = Date().addingTimeInterval(TimeInterval(menuState.interval.rawValue))
    }

    private func setInterval(_ interval: MonitorInterval) {
        store.interval = interval
        menuState.interval = interval
        scheduleNextAudit()
        renderAll()
    }

    private func notifyNewFindings(_ findings: [Finding], at date: Date) {
        let cooldown = max(3_600, TimeInterval(menuState.interval.rawValue))
        let eligible = findings.filter { finding in
            store.shouldNotify(
            key: finding.cooldownKey,
            now: date,
            cooldown: cooldown
            )
        }
        guard !eligible.isEmpty else { return }
        notifications.post(eligible)
        for finding in eligible {
            store.recordNotification(key: finding.cooldownKey, date: date)
        }
    }

    private func reviewFinding(id: String) {
        guard let finding = findingsByID[id] else {
            showFindingUnavailable(id: id)
            return
        }
        switch reviewPresenter.review(finding) {
        case .keepRunning:
            dismissFinding(id: id)
        case .quitProcess:
            let result = terminator.terminate(finding.process)
            reviewPresenter.showTerminationResult(result)
            if result == .requested { dismissFinding(id: id) }
        case .ignoreFutureAlerts:
            requestIgnoreFinding(id: id)
        }
    }

    private func reviewPortOwner(identity: String) {
        guard let process = processesByIdentity[identity] else { return }
        let canQuit = !TerminationPolicy.isProtected(
            sample: process,
            currentUserID: getuid(),
            currentProcessID: getpid()
        )
        switch reviewPresenter.reviewPortOwner(process, canQuit: canQuit) {
        case .quitProcess:
            reviewPresenter.showTerminationResult(terminator.terminate(process))
        case .ignoreFutureAlerts:
            if reviewPresenter.confirmIgnore(process) { ignoreProcess(process) }
        case .keepRunning:
            break
        }
    }

    private func requestIgnoreFinding(id: String) {
        guard let finding = findingsByID[id] else {
            showFindingUnavailable(id: id)
            return
        }
        if reviewPresenter.confirmIgnore(finding.process) { ignoreProcess(finding.process) }
    }

    private func ignoreProcess(_ process: ProcessSample) {
        let removedIDs = findingsByID.values
            .filter { $0.process.ignoreIdentity == process.ignoreIdentity }
            .map(\.id)
        store.ignore(identity: process.ignoreIdentity)
        store.removePendingFindings(ignoreIdentity: process.ignoreIdentity)
        findingsByID = findingsByID.filter {
            $0.value.process.ignoreIdentity != process.ignoreIdentity
        }
        menuState.findings.removeAll {
            $0.process.ignoreIdentity == process.ignoreIdentity
        }
        menuState.ignoredCount = store.ignoredCount
        for id in removedIDs { notifications.remove(id: id) }
        renderAll()
    }

    private func resetIgnoredProcesses() {
        guard reviewPresenter.confirmResetIgnoredProcesses() else { return }
        store.clearIgnoredIdentities()
        menuState.ignoredCount = 0
        renderAll()
    }

    private func showFindingUnavailable(id: String) {
        notifications.remove(id: id)
        reviewPresenter.showFindingUnavailable()
    }

    private func dismissFinding(id: String) {
        findingsByID.removeValue(forKey: id)
        store.removePendingFinding(id: id)
        notifications.remove(id: id)
        menuState.findings.removeAll { $0.id == id }
        renderAll()
    }

    private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            menuState.launchAtLogin = SMAppService.mainApp.status == .enabled
            menuState.errorMessage = nil
        } catch {
            menuState.errorMessage = error.localizedDescription
        }
        renderAll()
    }

    private func showOverview() {
        if overview == nil {
            let controller = OverviewWindowController(
                actions: OverviewActions(
                    refresh: { [weak self] in self?.requestScan() },
                    review: { [weak self] in self?.reviewPortOwner(identity: $0) },
                    quitVisible: { [weak self] in self?.quitVisibleProcesses(identities: $0) },
                    openSettings: { [weak self] in self?.showSettings() }
                ),
                preferences: preferences
            )
            controller.onClose = { [weak self] in self?.overview = nil }
            overview = controller
        }
        overview?.render(menuState)
        overview?.show()
    }

    private func showSettings() {
        if settings == nil {
            let controller = SettingsWindowController(
                actions: SettingsActions(
                    setInterval: { [weak self] in self?.setInterval($0) },
                    toggleLaunchAtLogin: { [weak self] in self?.toggleLaunchAtLogin() },
                    shortcutChanged: { [weak self] in self?.configureGlobalShortcut() },
                    updatesChanged: { [weak self] in self?.syncUpdateState() }
                ),
                preferences: preferences,
                updates: updates
            )
            controller.onClose = { [weak self] in self?.settings = nil }
            settings = controller
        }
        settings?.render(menuState)
        settings?.show()
    }

    private func syncUpdateState() {
        menuState.automaticallyChecksForUpdates = updates.automaticallyChecks
        menuState.automaticallyDownloadsUpdates = updates.automaticallyDownloads
        renderAll()
    }

    private func renderAll() {
        menu.render(menuState)
        overview?.render(menuState)
        settings?.render(menuState)
    }

    private func configureGlobalShortcut() {
        menuState.shortcutStatus = hotKey.apply(
            enabled: preferences.globalShortcutEnabled,
            shortcut: preferences.globalShortcut
        )
        renderAll()
    }

    private func quitVisibleProcesses(identities: [String]) {
        let processes = identities.compactMap { processesByIdentity[$0] }
        guard !processes.isEmpty,
              reviewPresenter.confirmQuitProcesses(processes)
        else { return }
        let results = processes.map { ($0, terminator.terminate($0)) }
        reviewPresenter.showBulkTerminationResult(results)
        requestScan()
    }
}
