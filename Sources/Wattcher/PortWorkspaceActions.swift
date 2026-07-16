import AppKit
import WattcherCore

@MainActor
struct PortWorkspaceActions {
    func open(_ process: ProcessSample) {
        guard let port = process.ports.first,
              let url = URL(string: "http://127.0.0.1:\(port.port)")
        else { return }
        NSWorkspace.shared.open(url)
    }

    func copyEndpoints(_ process: ProcessSample) {
        let value = process.ports.map(\.displayName).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    func revealExecutable(_ process: ProcessSample) {
        guard !process.executablePath.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: process.executablePath),
        ])
    }

    func openTerminal(_ process: ProcessSample) {
        guard !process.executablePath.isEmpty else { return }
        let directory = URL(fileURLWithPath: process.executablePath).deletingLastPathComponent().path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Terminal", directory]
        try? task.run()
    }
}
