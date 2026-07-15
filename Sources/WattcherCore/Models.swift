import Foundation

public enum MonitorInterval: Int, CaseIterable, Codable, Sendable {
    case tenMinutes = 600
    case fifteenMinutes = 900
    case twentyMinutes = 1_200
    case oneHour = 3_600
    case threeHours = 10_800
    case eightHours = 28_800

    public var title: String {
        switch self {
        case .tenMinutes: "10 minutes"
        case .fifteenMinutes: "15 minutes"
        case .twentyMinutes: "20 minutes"
        case .oneHour: "1 hour"
        case .threeHours: "3 hours"
        case .eightHours: "8 hours"
        }
    }
}

public struct BatteryState: Codable, Equatable, Sendable {
    public let percentage: Int?
    public let isCharging: Bool
    public let source: String

    public init(percentage: Int?, isCharging: Bool, source: String) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.source = source
    }
}

public struct ListeningPort: Codable, Hashable, Sendable {
    public let address: String
    public let port: Int

    public init(address: String, port: Int) {
        self.address = address
        self.port = port
    }

    public var isLoopback: Bool {
        if address == "::1" || address == "0:0:0:0:0:0:0:1" || address == "localhost" {
            return true
        }
        let octets = address.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4,
              octets.first == "127",
              octets.allSatisfy({ octet in
                  guard let value = UInt8(octet) else { return false }
                  return String(value) == octet || octet == "0"
              })
        else { return false }
        return true
    }

    public var displayName: String { "\(address):\(port)" }
}

public enum LaunchOrigin: String, Codable, Sendable {
    case foregroundApp
    case launchAgent
    case launchDaemon
    case backgroundProcess
    case userProcess
    case system

    public var label: String {
        switch self {
        case .foregroundApp: "App"
        case .launchAgent: "LaunchAgent"
        case .launchDaemon: "LaunchDaemon"
        case .backgroundProcess: "Background"
        case .userProcess: "User process"
        case .system: "System"
        }
    }
}

public struct ProcessSample: Codable, Identifiable, Sendable {
    public let pid: Int32
    public let parentPID: Int32
    public let userID: UInt32
    public let name: String
    public let executablePath: String
    public let cpuPercent: Double
    public let residentBytes: Int64
    public let ports: [ListeningPort]
    public let origin: LaunchOrigin
    public let startTimeIdentifier: UInt64
    public let cumulativeCPUTimeNanoseconds: UInt64
    public let cumulativeWakeups: UInt64

    public init(
        pid: Int32,
        parentPID: Int32,
        userID: UInt32,
        name: String,
        executablePath: String,
        cpuPercent: Double,
        residentBytes: Int64,
        ports: [ListeningPort],
        origin: LaunchOrigin,
        startTimeIdentifier: UInt64 = 0,
        cumulativeCPUTimeNanoseconds: UInt64 = 0,
        cumulativeWakeups: UInt64 = 0
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.userID = userID
        self.name = name
        self.executablePath = executablePath
        self.cpuPercent = cpuPercent
        self.residentBytes = residentBytes
        self.ports = ports
        self.origin = origin
        self.startTimeIdentifier = startTimeIdentifier
        self.cumulativeCPUTimeNanoseconds = cumulativeCPUTimeNanoseconds
        self.cumulativeWakeups = cumulativeWakeups
    }

    public var id: String { identity }
    public var identity: String { "\(pid):\(startTimeIdentifier):\(ignoreIdentity)" }
    public var ignoreIdentity: String { executablePath.isEmpty ? name : executablePath }
    public var residentMegabytes: Double { Double(residentBytes) / 1_048_576 }
}

public enum FindingKind: String, Codable, Sendable {
    case cpuAnomaly
    case memoryGrowth
    case newListener
    case newBackgroundProcess
}

public struct Finding: Codable, Identifiable, Sendable {
    public let id: String
    public let kind: FindingKind
    public let process: ProcessSample
    public let title: String
    public let evidence: String
    public let canQuit: Bool

    public init(
        id: String,
        kind: FindingKind,
        process: ProcessSample,
        title: String,
        evidence: String,
        canQuit: Bool
    ) {
        self.id = id
        self.kind = kind
        self.process = process
        self.title = title
        self.evidence = evidence
        self.canQuit = canQuit
    }

    public var cooldownKey: String {
        switch kind {
        case .newListener:
            "\(kind.rawValue):\(process.ignoreIdentity):\(process.ports.map(\.displayName).sorted().joined(separator: ","))"
        case .cpuAnomaly, .memoryGrowth, .newBackgroundProcess:
            "\(kind.rawValue):\(process.ignoreIdentity)"
        }
    }
}

public struct SystemSnapshot: Sendable {
    public let capturedAt: Date
    public let battery: BatteryState
    public let processes: [ProcessSample]

    public init(capturedAt: Date, battery: BatteryState, processes: [ProcessSample]) {
        self.capturedAt = capturedAt
        self.battery = battery
        self.processes = processes
    }
}

public struct PendingFinding: Codable, Sendable {
    public let finding: Finding
    public let createdAt: Date

    public init(finding: Finding, createdAt: Date) {
        self.finding = finding
        self.createdAt = createdAt
    }
}
