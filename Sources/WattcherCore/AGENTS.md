# WATTCHER CORE KNOWLEDGE

## OVERVIEW

Framework-free domain and system-observation target. It turns macOS command output into typed snapshots, maintains bounded baselines, and produces explainable findings plus termination eligibility.

## WHERE TO LOOK

| Concern | File | Contract |
|---|---|---|
| Shared values and interval presets | `Models.swift` | All cross-target values are `Sendable` |
| Process, port, battery collection | `SystemScanner.swift` | Concurrent `ps`/`lsof`/`pmset`; `libproc` enrichment |
| Bounded command execution | `CommandRunner.swift` | Combined pipe plus ten-second timeout |
| Launch origin | `LaunchOriginScanner.swift` | Reads standard user and local launchd plists once per scan |
| Baseline values | `MonitorState.swift` | Codable bounded process state |
| Baselines and findings | `RulesEngine.swift` | Warm-up, EWMA, cumulative activity deltas, external-listener rule |
| Termination eligibility | `TerminationPolicy.swift` | Current-user and protected-target checks |
| Audit overlap exclusion | `ScanGate.swift` | One in-flight manual or scheduled scan |
| Preferences and cooldown | `StateStore.swift` | Main-actor `UserDefaults`; Codable state |

## CONVENTIONS

- Keep parsing functions deterministic and fixture-testable.
- Treat command output as untrusted boundary data; malformed rows are skipped, command failures are typed.
- Key baselines by PID, process start time, and canonical executable path; prune absent identities.
- Key ignore decisions by executable path so a restart remains ignored.
- Evaluate a sample before folding it into the next EWMA baseline.
- Non-loopback new listeners are structural findings; loopback-only listeners are informational and silent in v1.
- Public models use explicit initializers to keep tests and app-target construction straightforward.

## ANTI-PATTERNS

- Do not add AppKit, UserNotifications, ServiceManagement, or UI state to this target.
- Do not parse human-formatted `lsof` tables; retain `-Fpcn` field output.
- Do not persist an unbounded process history.
- Do not use a global flat CPU threshold without the baseline and absolute floor.
- Do not mark first observations as anomalies.
- Do not turn command failures into empty successful snapshots.
- Do not relax `TerminationPolicy` to make a manual test easier.

## TEST GATES

```bash
swift test --filter CommandRunnerTests
swift test --filter SystemScannerTests
swift test --filter RulesEngineTests
```
