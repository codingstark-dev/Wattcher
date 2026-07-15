import Foundation

public struct RulesEngine: Sendable {
    public init() {}

    public func evaluate(
        samples: [ProcessSample],
        state: MonitorState,
        currentUserID: UInt32,
        currentProcessID: Int32,
        capturedAt: Date = Date()
    ) -> Evaluation {
        var nextState = state
        var findings = [Finding]()
        let activeIdentities = Set(samples.map(\.identity))
        nextState.baselines = nextState.baselines.filter { activeIdentities.contains($0.key) }

        for sample in samples {
            let identity = sample.identity
            guard sample.userID == currentUserID,
                  !state.ignoredIdentities.contains(sample.ignoreIdentity),
                  !TerminationPolicy.isProtected(
                    sample: sample,
                    currentUserID: currentUserID,
                    currentProcessID: currentProcessID
                  )
            else { continue }

            let previous = state.baselines[identity]
            let activity = measuredActivity(
                sample: sample,
                previous: previous,
                capturedAt: capturedAt
            )
            var baseline = updatedBaseline(
                sample: sample,
                observedCPU: activity.cpuPercent,
                capturedAt: capturedAt,
                previous: previous
            )
            if let previous {
                let cpuAnomaly = activity.cpuPercent >= 8
                    && activity.cpuPercent >= max(previous.cpuAverage * 3, previous.cpuAverage + 5)
                baseline.consecutiveCPUAnomalies = cpuAnomaly
                    ? previous.consecutiveCPUAnomalies + 1 : 0
                if baseline.consecutiveCPUAnomalies >= 2 {
                    findings.append(cpuFinding(
                        sample: sample,
                        baseline: previous,
                        activity: activity
                    ))
                }

                let memoryAnomaly = sample.residentMegabytes >= 512
                    && sample.residentBytes >= Int64(previous.residentAverage * 1.5)
                    && Double(sample.residentBytes) - previous.residentAverage >= 268_435_456
                baseline.consecutiveMemoryAnomalies = memoryAnomaly
                    ? previous.consecutiveMemoryAnomalies + 1 : 0
                if baseline.consecutiveMemoryAnomalies >= 2 {
                    findings.append(memoryFinding(sample: sample, baseline: previous))
                }

                let newPorts = Set(sample.ports).subtracting(previous.ports)
                    .filter { !$0.isLoopback }
                    .sorted { $0.displayName < $1.displayName }
                for external in newPorts {
                    findings.append(portFinding(sample: sample, port: external))
                }
            } else if state.hasCompletedScan, shouldFlagNewBackground(sample) {
                findings.append(backgroundFinding(sample: sample))
            }
            nextState.baselines[identity] = baseline
        }
        nextState.hasCompletedScan = true
        return Evaluation(findings: findings, state: nextState)
    }

    private func updatedBaseline(
        sample: ProcessSample,
        observedCPU: Double,
        capturedAt: Date,
        previous: ProcessBaseline?
    ) -> ProcessBaseline {
        guard let previous else {
            return ProcessBaseline(
                cpuAverage: observedCPU,
                residentAverage: Double(sample.residentBytes),
                ports: Set(sample.ports),
                sampleCount: 1,
                cumulativeCPUTimeNanoseconds: sample.cumulativeCPUTimeNanoseconds,
                cumulativeWakeups: sample.cumulativeWakeups,
                capturedAt: capturedAt
            )
        }
        let weight = 0.25
        return ProcessBaseline(
            cpuAverage: previous.cpuAverage * (1 - weight) + observedCPU * weight,
            residentAverage: previous.residentAverage * (1 - weight)
                + Double(sample.residentBytes) * weight,
            ports: Set(sample.ports),
            sampleCount: previous.sampleCount + 1,
            consecutiveCPUAnomalies: previous.consecutiveCPUAnomalies,
            consecutiveMemoryAnomalies: previous.consecutiveMemoryAnomalies,
            cumulativeCPUTimeNanoseconds: sample.cumulativeCPUTimeNanoseconds,
            cumulativeWakeups: sample.cumulativeWakeups,
            capturedAt: capturedAt
        )
    }

    private func cpuFinding(
        sample: ProcessSample,
        baseline: ProcessBaseline,
        activity: MeasuredActivity
    ) -> Finding {
        let ratio = activity.cpuPercent / max(baseline.cpuAverage, 0.1)
        return Finding(
            id: "cpu:\(sample.identity)",
            kind: .cpuAnomaly,
            process: sample,
            title: "\(sample.name) has sustained background activity",
            evidence: String(
                format: "%.1f%% interval CPU, %.1fx its %.1f%% baseline, %llu wakeups. Estimated battery impact only.",
                activity.cpuPercent,
                ratio,
                baseline.cpuAverage,
                activity.wakeupDelta
            ),
            canQuit: true
        )
    }

    private func memoryFinding(sample: ProcessSample, baseline: ProcessBaseline) -> Finding {
        let baselineMegabytes = baseline.residentAverage / 1_048_576
        return Finding(
            id: "memory:\(sample.identity)",
            kind: .memoryGrowth,
            process: sample,
            title: "\(sample.name) is using more memory than usual",
            evidence: String(
                format: "%.0f MB RAM, up from a %.0f MB baseline.",
                sample.residentMegabytes,
                baselineMegabytes
            ),
            canQuit: true
        )
    }

    private func portFinding(sample: ProcessSample, port: ListeningPort) -> Finding {
        Finding(
            id: "port:\(sample.identity):\(port.displayName)",
            kind: .newListener,
            process: sample,
            title: "\(sample.name) opened a new listening port",
            evidence: "TCP \(port.displayName) is reachable beyond loopback; RAM belongs to the process, not the port.",
            canQuit: true
        )
    }

    private func backgroundFinding(sample: ProcessSample) -> Finding {
        let ports = sample.ports.filter { !$0.isLoopback }.map(\.displayName).joined(separator: ", ")
        let detail = ports.isEmpty ? "no external listener" : "listening on \(ports)"
        return Finding(
            id: "background:\(sample.identity)",
            kind: .newBackgroundProcess,
            process: sample,
            title: "New \(sample.origin.label.lowercased()) process: \(sample.name)",
            evidence: String(
                format: "New background origin, %.0f MB RAM, %@. Review whether you expected it.",
                sample.residentMegabytes,
                detail
            ),
            canQuit: true
        )
    }

    private func shouldFlagNewBackground(_ sample: ProcessSample) -> Bool {
        switch sample.origin {
        case .launchAgent, .launchDaemon:
            true
        case .backgroundProcess:
            sample.ports.contains { !$0.isLoopback }
        case .foregroundApp, .userProcess, .system:
            false
        }
    }

    private func measuredActivity(
        sample: ProcessSample,
        previous: ProcessBaseline?,
        capturedAt: Date
    ) -> MeasuredActivity {
        guard let previous,
              sample.cumulativeCPUTimeNanoseconds > 0
                || previous.cumulativeCPUTimeNanoseconds > 0,
              sample.cumulativeCPUTimeNanoseconds >= previous.cumulativeCPUTimeNanoseconds,
              sample.cumulativeWakeups >= previous.cumulativeWakeups,
              previous.capturedAt != .distantPast
        else {
            return MeasuredActivity(cpuPercent: sample.cpuPercent, wakeupDelta: 0)
        }
        let elapsed = capturedAt.timeIntervalSince(previous.capturedAt)
        guard elapsed > 0 else {
            return MeasuredActivity(cpuPercent: sample.cpuPercent, wakeupDelta: 0)
        }
        let cpuDelta = sample.cumulativeCPUTimeNanoseconds - previous.cumulativeCPUTimeNanoseconds
        let cpuPercent = Double(cpuDelta) / 1_000_000_000 / elapsed * 100
        return MeasuredActivity(
            cpuPercent: cpuPercent,
            wakeupDelta: sample.cumulativeWakeups - previous.cumulativeWakeups
        )
    }
}

private struct MeasuredActivity {
    let cpuPercent: Double
    let wakeupDelta: UInt64
}
