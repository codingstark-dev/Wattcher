import XCTest
@testable import WattcherCore

final class CommandRunnerTests: XCTestCase {
    func testTimeoutForceStopsTermIgnoringCollector() async {
        do {
            _ = try await CommandRunner.run(
                path: "/bin/sh",
                arguments: ["-c", "trap '' TERM; while :; do :; done"],
                acceptedStatuses: [0],
                timeout: 0.1,
                terminationGrace: 0.1
            )
            XCTFail("Expected the command to time out")
        } catch let ScanError.timedOut(path) {
            XCTAssertEqual(path, "/bin/sh")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTimeoutClosesPipeRetainedByExitedCollectorsChild() async {
        let startedAt = Date()
        do {
            _ = try await CommandRunner.run(
                path: "/bin/sh",
                arguments: ["-c", "(sleep 1) & exit 0"],
                acceptedStatuses: [0],
                timeout: 0.1,
                terminationGrace: 0.1
            )
            XCTFail("Expected the retained pipe to time out")
        } catch let ScanError.timedOut(path) {
            XCTAssertEqual(path, "/bin/sh")
            XCTAssertLessThan(Date().timeIntervalSince(startedAt), 0.75)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
