import AppKit
import WattcherCore

enum ReviewDecision {
    case keepRunning
    case quitProcess
    case ignoreFutureAlerts
}

@MainActor
struct ReviewPresenter {
    func review(_ finding: Finding) -> ReviewDecision {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = finding.title
        alert.informativeText = "\(finding.evidence)\n\nOrigin: \(finding.process.origin.label) · PID \(finding.process.pid)"
        return runDecisionAlert(alert, canQuit: finding.canQuit)
    }

    func reviewPortOwner(_ process: ProcessSample, canQuit: Bool) -> ReviewDecision {
        let ports = process.ports.map(\.displayName).joined(separator: ", ")
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "\(process.name) owns listening TCP ports"
        alert.informativeText = String(
            format: "Ports: %@\nCPU: %.1f%% · RAM: %.0f MB\nOrigin: %@ · PID %d\n%@",
            ports,
            process.cpuPercent,
            process.residentMegabytes,
            process.origin.label,
            process.pid,
            process.executablePath
        )
        return runDecisionAlert(alert, canQuit: canQuit)
    }

    func confirmIgnore(_ process: ProcessSample) -> Bool {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Ignore future alerts from \(process.name)?"
        alert.informativeText = "Wattcher stores up to 200 recently ignored executable paths. The oldest expires when the limit is reached; Reset Ignored Processes clears all:\n\(process.ignoreIdentity)"
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Ignore Future Alerts")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func confirmResetIgnoredProcesses() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Reset all ignored processes?"
        alert.informativeText = "Future audits can alert on these executables again."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func showFindingUnavailable() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "This finding is no longer available"
        alert.informativeText = "The process changed or the review window expired. Run Check Now for current evidence."
        alert.runModal()
    }

    func showTerminationResult(_ result: TerminationResult) {
        let alert = NSAlert()
        switch result {
        case .requested:
            alert.messageText = "Quit requested"
            alert.informativeText = "Wattcher sent SIGTERM. A launch-managed process may start again."
            alert.alertStyle = .informational
        case let .refused(reason):
            alert.messageText = "Wattcher did not quit the process"
            alert.informativeText = reason
            alert.alertStyle = .warning
        }
        alert.runModal()
    }

    func confirmQuitProcesses(_ processes: [ProcessSample]) -> Bool {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let names = processes.prefix(12).map { "• \($0.name) (PID \($0.pid))" }.joined(separator: "\n")
        let remainder = processes.count > 12 ? "\n…and \(processes.count - 12) more" : ""
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Quit \(processes.count) visible port owners?"
        alert.informativeText = "Wattcher will revalidate every process and send SIGTERM only to safe, current-user targets.\n\n\(names)\(remainder)"
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit Safe Processes")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func showBulkTerminationResult(_ results: [(ProcessSample, TerminationResult)]) {
        let requested = results.filter { $0.1 == .requested }.count
        let refused = results.count - requested
        let alert = NSAlert()
        alert.messageText = "Quit requested for \(requested) process\(requested == 1 ? "" : "es")"
        alert.informativeText = refused == 0
            ? "Each process received SIGTERM and may take a moment to exit."
            : "\(refused) target\(refused == 1 ? " was" : "s were") protected, stale, or already stopped."
        alert.alertStyle = refused == 0 ? .informational : .warning
        alert.runModal()
    }

    private func runDecisionAlert(_ alert: NSAlert, canQuit: Bool) -> ReviewDecision {
        alert.addButton(withTitle: "Keep Running")
        if canQuit { alert.addButton(withTitle: "Quit Process") }
        alert.addButton(withTitle: "Ignore Future Alerts")
        let response = alert.runModal()
        if canQuit, response == .alertSecondButtonReturn { return .quitProcess }
        if response == (canQuit ? .alertThirdButtonReturn : .alertSecondButtonReturn) {
            return .ignoreFutureAlerts
        }
        return .keepRunning
    }
}
