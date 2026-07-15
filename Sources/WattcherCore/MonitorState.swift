import Foundation

public struct ProcessBaseline: Codable, Equatable, Sendable {
    public var cpuAverage: Double
    public var residentAverage: Double
    public var ports: Set<ListeningPort>
    public var sampleCount: Int
    public var consecutiveCPUAnomalies: Int
    public var consecutiveMemoryAnomalies: Int
    public var cumulativeCPUTimeNanoseconds: UInt64
    public var cumulativeWakeups: UInt64
    public var capturedAt: Date

    public init(
        cpuAverage: Double,
        residentAverage: Double,
        ports: Set<ListeningPort>,
        sampleCount: Int,
        consecutiveCPUAnomalies: Int = 0,
        consecutiveMemoryAnomalies: Int = 0,
        cumulativeCPUTimeNanoseconds: UInt64 = 0,
        cumulativeWakeups: UInt64 = 0,
        capturedAt: Date = .distantPast
    ) {
        self.cpuAverage = cpuAverage
        self.residentAverage = residentAverage
        self.ports = ports
        self.sampleCount = sampleCount
        self.consecutiveCPUAnomalies = consecutiveCPUAnomalies
        self.consecutiveMemoryAnomalies = consecutiveMemoryAnomalies
        self.cumulativeCPUTimeNanoseconds = cumulativeCPUTimeNanoseconds
        self.cumulativeWakeups = cumulativeWakeups
        self.capturedAt = capturedAt
    }
}

public struct MonitorState: Codable, Equatable, Sendable {
    public var baselines: [String: ProcessBaseline]
    public var ignoredIdentities: Set<String>
    public var ignoredIdentityOrder: [String]
    public var hasCompletedScan: Bool

    public init(
        baselines: [String: ProcessBaseline] = [:],
        ignoredIdentities: Set<String> = [],
        ignoredIdentityOrder: [String] = [],
        hasCompletedScan: Bool = false
    ) {
        self.baselines = baselines
        self.ignoredIdentities = ignoredIdentities
        self.ignoredIdentityOrder = ignoredIdentityOrder
        self.hasCompletedScan = hasCompletedScan
    }
}

public struct Evaluation: Sendable {
    public let findings: [Finding]
    public let state: MonitorState

    public init(findings: [Finding], state: MonitorState) {
        self.findings = findings
        self.state = state
    }
}
