import Foundation
import Darwin
import WattcherSystem

public enum ScanError: LocalizedError, Sendable {
    case commandFailed(path: String, status: Int32, message: String)
    case invalidOutput(path: String)
    case timedOut(path: String)

    public var errorDescription: String? {
        switch self {
        case let .commandFailed(path, status, message):
            "\(path) exited with status \(status): \(message)"
        case let .invalidOutput(path):
            "Could not read the output from \(path)."
        case let .timedOut(path):
            "\(path) did not finish within 10 seconds."
        }
    }
}

public struct ProcessIdentity: Equatable, Sendable {
    public let pid: Int32
    public let userID: UInt32
    public let executablePath: String
    public let startTimeIdentifier: UInt64

    public init(
        pid: Int32,
        userID: UInt32,
        executablePath: String,
        startTimeIdentifier: UInt64
    ) {
        self.pid = pid
        self.userID = userID
        self.executablePath = executablePath
        self.startTimeIdentifier = startTimeIdentifier
    }
}

public struct SystemScanner: Sendable {
    public init() {}

    public func scan() async throws -> SystemSnapshot {
        async let portsOutput = CommandRunner.run(
            path: "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"],
            acceptedStatuses: [0, 1]
        )
        async let processOutput = CommandRunner.run(
            path: "/bin/ps",
            arguments: ["-axo", "pid=,ppid=,uid=,pcpu=,rss=,comm="],
            acceptedStatuses: [0]
        )
        async let batteryOutput = CommandRunner.run(
            path: "/usr/bin/pmset",
            arguments: ["-g", "batt"],
            acceptedStatuses: [0]
        )

        let (portsText, processText, batteryText) = try await (
            portsOutput,
            processOutput,
            batteryOutput
        )
        if portsText.contains("lsof:") {
            throw ScanError.invalidOutput(path: "/usr/sbin/lsof")
        }
        let ports = Self.parsePorts(portsText)
        let parsed = Self.parseProcesses(processText, portsByPID: ports)
        let origins = LaunchOriginScanner()
        let processes = parsed
            .filter { $0.userID == getuid() }
            .compactMap { Self.enrich($0, origins: origins) }
            .filter { $0.userID == getuid() }
        return SystemSnapshot(
            capturedAt: Date(),
            battery: Self.parseBattery(batteryText),
            processes: processes
        )
    }

    public func currentIdentity(pid: Int32) throws -> ProcessIdentity? {
        guard let metrics = Self.readMetrics(pid: pid) else { return nil }
        return ProcessIdentity(
            pid: pid,
            userID: metrics.userID,
            executablePath: metrics.path,
            startTimeIdentifier: metrics.startTimeIdentifier
        )
    }

    private static func enrich(
        _ sample: ProcessSample,
        origins: LaunchOriginScanner
    ) -> ProcessSample? {
        guard let metrics = readMetrics(pid: sample.pid) else { return nil }
        return ProcessSample(
            pid: sample.pid,
            parentPID: sample.parentPID,
            userID: metrics.userID,
            name: URL(fileURLWithPath: metrics.path).lastPathComponent,
            executablePath: metrics.path,
            cpuPercent: sample.cpuPercent,
            residentBytes: Int64(clamping: metrics.residentBytes),
            ports: sample.ports,
            origin: origins.classify(path: metrics.path, parentPID: sample.parentPID),
            startTimeIdentifier: metrics.startTimeIdentifier,
            cumulativeCPUTimeNanoseconds: metrics.cpuTimeNanoseconds,
            cumulativeWakeups: metrics.wakeups
        )
    }

    private static func readMetrics(pid: Int32) -> ProcessMetrics? {
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        var userID: UInt32 = 0
        var startTime: UInt64 = 0
        var cpuTime: UInt64 = 0
        var residentBytes: UInt64 = 0
        var wakeups: UInt64 = 0
        let result = path.withUnsafeMutableBufferPointer { buffer in
            wattcher_read_process(
                pid,
                buffer.baseAddress,
                Int32(buffer.count),
                &userID,
                &startTime,
                &cpuTime,
                &residentBytes,
                &wakeups
            )
        }
        guard result == 0 else { return nil }
        let pathBytes = path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return ProcessMetrics(
            path: String(decoding: pathBytes, as: UTF8.self),
            userID: userID,
            startTimeIdentifier: startTime,
            cpuTimeNanoseconds: cpuTime,
            residentBytes: residentBytes,
            wakeups: wakeups
        )
    }

    static func parseProcesses(
        _ output: String,
        portsByPID: [Int32: [ListeningPort]]
    ) -> [ProcessSample] {
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(maxSplits: 5, whereSeparator: \.isWhitespace)
            guard fields.count == 6,
                  let pid = Int32(fields[0]),
                  let parentPID = Int32(fields[1]),
                  let userID = UInt32(fields[2]),
                  let cpu = Double(fields[3]),
                  let residentKilobytes = Int64(fields[4])
            else { return nil }

            let path = String(fields[5])
            let origin: LaunchOrigin
            if path.hasPrefix("/System/") || path.hasPrefix("/usr/libexec/") {
                origin = .system
            } else if path.contains(".app/Contents/MacOS/") {
                origin = .foregroundApp
            } else {
                origin = parentPID == 1 ? .backgroundProcess : .userProcess
            }
            return ProcessSample(
                pid: pid,
                parentPID: parentPID,
                userID: userID,
                name: URL(fileURLWithPath: path).lastPathComponent,
                executablePath: path,
                cpuPercent: cpu,
                residentBytes: residentKilobytes * 1_024,
                ports: portsByPID[pid] ?? [],
                origin: origin
            )
        }
    }

    static func parsePorts(_ output: String) -> [Int32: [ListeningPort]] {
        var currentPID: Int32?
        var ports = [Int32: Set<ListeningPort>]()
        for lineSlice in output.split(whereSeparator: \.isNewline) {
            let line = String(lineSlice)
            guard let marker = line.first else { continue }
            let value = String(line.dropFirst())
            if marker == "p" {
                currentPID = Int32(value)
            } else if marker == "n", let pid = currentPID,
                      let port = parseEndpoint(value) {
                ports[pid, default: []].insert(port)
            }
        }
        return ports.mapValues { $0.sorted { $0.port < $1.port } }
    }

    static func parseBattery(_ output: String) -> BatteryState {
        let line = output.split(whereSeparator: \.isNewline)
            .map(String.init)
            .first { $0.contains("%") } ?? output
        let percentage = line.split(separator: "%").first.flatMap { prefix in
            prefix.split(whereSeparator: { !$0.isNumber }).last.flatMap { Int($0) }
        }
        let lower = line.lowercased()
        let charging = !lower.contains("discharging")
            && (lower.contains("charging") || lower.contains("charged"))
        let source = output.contains("AC Power") ? "AC Power" : "Battery Power"
        return BatteryState(percentage: percentage, isCharging: charging, source: source)
    }

    private static func parseEndpoint(_ value: String) -> ListeningPort? {
        let endpoint = value.split(separator: " ").first.map(String.init) ?? value
        guard let separator = endpoint.lastIndex(of: ":"),
              let port = Int(endpoint[endpoint.index(after: separator)...])
        else { return nil }
        var address = String(endpoint[..<separator])
        if address.hasPrefix("[") && address.hasSuffix("]") {
            address.removeFirst()
            address.removeLast()
        }
        return ListeningPort(address: address, port: port)
    }

}

private struct ProcessMetrics {
    let path: String
    let userID: UInt32
    let startTimeIdentifier: UInt64
    let cpuTimeNanoseconds: UInt64
    let residentBytes: UInt64
    let wakeups: UInt64
}
