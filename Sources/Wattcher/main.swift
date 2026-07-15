import AppKit
import Darwin
import WattcherCore

let arguments = Set(CommandLine.arguments.dropFirst())

if arguments.contains("--help") {
    print("""
    Wattcher
      --scan-once  Print one live system snapshot and exit.
      --help       Show this help.
    """)
} else if arguments.contains("--scan-once") {
    Task.detached {
        do {
            let snapshot = try await SystemScanner().scan()
            let listeners = snapshot.processes.filter { !$0.ports.isEmpty }
            let battery = snapshot.battery.percentage.map(String.init) ?? "unknown"
            print("Battery: \(battery)% (\(snapshot.battery.source))")
            print("Processes: \(snapshot.processes.count); listening: \(listeners.count)")
            for process in listeners.sorted(by: { $0.cpuPercent > $1.cpuPercent }) {
                let ports = process.ports.map(\.displayName).joined(separator: ", ")
                print(String(
                    format: "%@ pid=%d cpu=%.1f%% ram=%.0fMB ports=%@",
                    process.name,
                    process.pid,
                    process.cpuPercent,
                    process.residentMegabytes,
                    ports
                ))
            }
            exit(EXIT_SUCCESS)
        } catch {
            fputs("Wattcher scan failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
    dispatchMain()
} else {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
}
