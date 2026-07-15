import XCTest
@testable import WattcherCore

final class RulesEngineTests: XCTestCase {
    private let engine = RulesEngine()
    private let userID: UInt32 = 501
    private let processID: Int32 = 9_999

    func testFirstSampleWarmsBaselineWithoutFinding() {
        let result = evaluate(sample(cpu: 2))

        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertEqual(result.state.baselines["123:0:/usr/local/bin/demo"]?.sampleCount, 1)
    }

    func testSustainedCPUAnomalyRequiresTwoHighSamples() {
        let warm = evaluate(sample(cpu: 1))
        let firstHigh = evaluate(sample(cpu: 20), state: warm.state)
        let secondHigh = evaluate(sample(cpu: 20), state: firstHigh.state)

        XCTAssertTrue(firstHigh.findings.isEmpty)
        XCTAssertEqual(secondHigh.findings.map(\.kind), [.cpuAnomaly])
        XCTAssertTrue(secondHigh.findings[0].evidence.contains("Estimated battery impact only"))
    }

    func testCumulativeCPUUsesActivityBetweenAudits() {
        let start = Date(timeIntervalSince1970: 1_000)
        let baseline = engine.evaluate(
            samples: [sample(cpu: 1, cumulativeCPU: 1_000_000_000)],
            state: MonitorState(),
            currentUserID: userID,
            currentProcessID: processID,
            capturedAt: start
        )
        let first = engine.evaluate(
            samples: [sample(cpu: 1, cumulativeCPU: 2_000_000_000)],
            state: baseline.state,
            currentUserID: userID,
            currentProcessID: processID,
            capturedAt: start.addingTimeInterval(10)
        )
        let second = engine.evaluate(
            samples: [sample(cpu: 1, cumulativeCPU: 3_000_000_000)],
            state: first.state,
            currentUserID: userID,
            currentProcessID: processID,
            capturedAt: start.addingTimeInterval(20)
        )

        XCTAssertTrue(first.findings.isEmpty)
        XCTAssertEqual(second.findings.map(\.kind), [.cpuAnomaly])
        XCTAssertTrue(second.findings[0].evidence.contains("10.0% interval CPU"))
    }

    func testNewExternalListenerIsFlaggedAfterWarmup() {
        let warm = evaluate(sample(cpu: 1))
        let listener = sample(
            cpu: 1,
            ports: [ListeningPort(address: "*", port: 8080)]
        )
        let result = evaluate(listener, state: warm.state)

        XCTAssertEqual(result.findings.map(\.kind), [.newListener])
        XCTAssertTrue(result.findings[0].evidence.contains("RAM belongs to the process"))
    }

    func testLoopbackListenerDoesNotCreateSecurityFinding() {
        let warm = evaluate(sample(cpu: 1))
        let listener = sample(
            cpu: 1,
            ports: [ListeningPort(address: "127.0.0.1", port: 8080)]
        )

        XCTAssertTrue(evaluate(listener, state: warm.state).findings.isEmpty)
    }

    func testEntireIPv4LoopbackRangeIsLocal() {
        XCTAssertTrue(ListeningPort(address: "127.0.0.2", port: 8080).isLoopback)
        XCTAssertTrue(ListeningPort(address: "127.255.255.255", port: 8080).isLoopback)
        XCTAssertFalse(ListeningPort(address: "128.0.0.1", port: 8080).isLoopback)
    }

    func testScanGateRejectsOverlapUntilCurrentScanEnds() {
        var gate = ScanGate()

        XCTAssertTrue(gate.begin())
        XCTAssertFalse(gate.begin())
        gate.end()
        XCTAssertTrue(gate.begin())
    }

    func testSystemProcessIsProtected() {
        let system = sample(cpu: 99, path: "/System/Library/CoreServices/demo")

        XCTAssertTrue(TerminationPolicy.isProtected(
            sample: system,
            currentUserID: userID,
            currentProcessID: processID
        ))
    }

    func testNewLaunchAgentIsFlaggedAfterInitialScan() {
        let warm = evaluate(sample(cpu: 1))
        let agent = sample(
            cpu: 0,
            path: "/Users/test/Library/Application Support/demo-agent",
            pid: 456,
            origin: .launchAgent
        )

        XCTAssertEqual(evaluate(agent, state: warm.state).findings.map(\.kind), [.newBackgroundProcess])
    }

    func testIntervalsMatchRequestedPresets() {
        XCTAssertEqual(MonitorInterval.allCases.map(\.rawValue), [600, 900, 1_200, 3_600, 10_800, 28_800])
    }

    private func evaluate(
        _ sample: ProcessSample,
        state: MonitorState = MonitorState()
    ) -> Evaluation {
        engine.evaluate(
            samples: [sample],
            state: state,
            currentUserID: userID,
            currentProcessID: processID
        )
    }

    private func sample(
        cpu: Double,
        ports: [ListeningPort] = [],
        path: String = "/usr/local/bin/demo",
        pid: Int32 = 123,
        origin: LaunchOrigin = .backgroundProcess,
        cumulativeCPU: UInt64 = 0
    ) -> ProcessSample {
        ProcessSample(
            pid: pid,
            parentPID: 1,
            userID: userID,
            name: "demo",
            executablePath: path,
            cpuPercent: cpu,
            residentBytes: 64 * 1_048_576,
            ports: ports,
            origin: path.hasPrefix("/System/") ? .system : origin,
            cumulativeCPUTimeNanoseconds: cumulativeCPU
        )
    }
}
