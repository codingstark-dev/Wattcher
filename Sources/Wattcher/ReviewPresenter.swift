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
