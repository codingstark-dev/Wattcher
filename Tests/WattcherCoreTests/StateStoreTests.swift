import XCTest
@testable import WattcherCore

@MainActor
final class StateStoreTests: XCTestCase {
    private let suiteName = "app.wattcher.tests.StateStore"

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testPendingFindingSurvivesStoreRecreationUntilDismissed() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let finding = Finding(
            id: "cpu:demo",
            kind: .cpuAnomaly,
            process: sample,
            title: "Review demo",
            evidence: "Measured evidence",
            canQuit: true
        )

        _ = StateStore(defaults: defaults).mergePendingFindings([finding], at: Date())
        let restored = StateStore(defaults: defaults)

        XCTAssertEqual(restored.loadPendingFindings().map(\.id), [finding.id])
        restored.removePendingFinding(id: finding.id)
        XCTAssertTrue(restored.loadPendingFindings().isEmpty)
    }

    func testIgnoredProcessSetIsBoundedAndResettable() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = StateStore(defaults: defaults)

        for index in 0..<205 {
            store.ignore(identity: "/tmp/process-\(index)")
        }

        XCTAssertEqual(store.ignoredCount, 200)
        XCTAssertFalse(store.loadState().ignoredIdentities.contains("/tmp/process-0"))
        XCTAssertTrue(store.loadState().ignoredIdentities.contains("/tmp/process-204"))
        store.clearIgnoredIdentities()
        XCTAssertEqual(store.ignoredCount, 0)
    }

    private var sample: ProcessSample {
        ProcessSample(
            pid: 42,
            parentPID: 1,
            userID: 501,
            name: "demo",
            executablePath: "/usr/local/bin/demo",
            cpuPercent: 12,
            residentBytes: 64 * 1_048_576,
            ports: [],
            origin: .backgroundProcess,
            startTimeIdentifier: 99
        )
    }
}
