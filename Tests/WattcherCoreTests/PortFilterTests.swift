import Testing
@testable import WattcherCore

struct PortFilterTests {
    @Test func defaultViewKeepsLocalDevelopmentListeners() {
        let node = sample(
            name: "node",
            path: "/opt/homebrew/bin/node",
            ports: [ListeningPort(address: "127.0.0.1", port: 3_000)]
        )
        let sharing = sample(
            name: "sharingd",
            path: "/usr/libexec/sharingd",
            ports: [ListeningPort(address: "*", port: 5_000)]
        )

        #expect(PortFilter.filtered([sharing, node], query: "", showAll: false).map(\.name) == ["node"])
        #expect(PortFilter.filtered([sharing, node], query: "", showAll: true).count == 2)
    }

    @Test func searchMatchesPortProcessPathAndPID() {
        let server = sample(
            pid: 42,
            name: "AgentServer",
            path: "/Users/me/Projects/Agent/server",
            ports: [ListeningPort(address: "::1", port: 49_306)]
        )

        #expect(PortFilter.filtered([server], query: "49306", showAll: true).count == 1)
        #expect(PortFilter.filtered([server], query: "agentserver", showAll: true).count == 1)
        #expect(PortFilter.filtered([server], query: "projects/agent", showAll: true).count == 1)
        #expect(PortFilter.filtered([server], query: "42", showAll: true).count == 1)
        #expect(PortFilter.filtered([server], query: "missing", showAll: true).isEmpty)
    }

    private func sample(
        pid: Int32 = 100,
        name: String,
        path: String,
        ports: [ListeningPort]
    ) -> ProcessSample {
        ProcessSample(
            pid: pid,
            parentPID: 1,
            userID: 501,
            name: name,
            executablePath: path,
            cpuPercent: 2,
            residentBytes: 64 * 1_048_576,
            ports: ports,
            origin: .userProcess
        )
    }
}
