import XCTest
@testable import WattcherCore

final class SystemScannerTests: XCTestCase {
    func testParsesProcessAndOwnedPort() throws {
        let ports = [Int32(123): [ListeningPort(address: "*", port: 8080)]]
        let result = SystemScanner.parseProcesses(
            " 123 1 501 12.5 2048 /usr/local/bin/demo\n",
            portsByPID: ports
        )

        let process = try XCTUnwrap(result.first)
        XCTAssertEqual(process.pid, 123)
        XCTAssertEqual(process.userID, 501)
        XCTAssertEqual(process.cpuPercent, 12.5)
        XCTAssertEqual(process.residentBytes, 2_097_152)
        XCTAssertEqual(process.ports, ports[123])
        XCTAssertEqual(process.origin, .backgroundProcess)
    }

    func testParsesAndDeduplicatesListeningPorts() {
        let output = """
        p42
        cdemo
        f10
        n*:8080
        f11
        n*:8080
        f12
        n[::1]:3000
        """

        XCTAssertEqual(
            SystemScanner.parsePorts(output)[42],
            [ListeningPort(address: "::1", port: 3000), ListeningPort(address: "*", port: 8080)]
        )
    }

    func testDischargingIsNotMistakenForCharging() {
        let battery = SystemScanner.parseBattery(
            "Now drawing from 'Battery Power'\n -InternalBattery-0 72%; discharging; 4:00 remaining\n"
        )

        XCTAssertEqual(battery.percentage, 72)
        XCTAssertFalse(battery.isCharging)
        XCTAssertEqual(battery.source, "Battery Power")
    }

    func testLaunchAgentAppPathTakesPrecedenceOverForegroundHeuristic() {
        let path = "/tmp/sample.app/Contents/MacOS/sample"
        let scanner = LaunchOriginScanner(agentPaths: [path], daemonPaths: [])

        XCTAssertEqual(scanner.classify(path: path, parentPID: 1), .launchAgent)
    }
}
