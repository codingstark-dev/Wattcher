# PROJECT KNOWLEDGE BASE

**Generated:** 2026-07-16
**Commit:** Unborn repository
**Branch:** master

## OVERVIEW

Native macOS 14+ menu-bar monitor built with Swift 6, AppKit, SwiftPM, and public command-line system interfaces. Wattcher runs local scheduled audits of battery state, process CPU/RAM, launch origin, and listening TCP ports; deterministic rules produce reviewable findings without AI or administrator access.

## STRUCTURE

```text
Wattcher/
├── Sources/Wattcher/          # AppKit composition root and user-facing actions
├── Sources/WattcherCore/      # Typed collection, baseline, and policy engine
├── Tests/WattcherCoreTests/   # Parser and rules boundaries
├── Resources/Info.plist       # LSUIElement app-bundle metadata
├── scripts/                   # Local bundle and notarized-release workflows
└── Package.swift              # Swift 6 package and target boundaries
```

## WHERE TO LOOK

| Task | Location | Notes |
|---|---|---|
| Change audit intervals | `Sources/WattcherCore/Models.swift` | `MonitorInterval` is the single preset source |
| Collect processes, ports, battery | `Sources/WattcherCore/SystemScanner.swift` | `ps`, `libproc`, `lsof`, and `pmset` |
| Tune anomaly thresholds | `Sources/WattcherCore/RulesEngine.swift` | Preserve warm-up, sustained checks, and evidence text |
| Change process protection | `Sources/WattcherCore/TerminationPolicy.swift`, `Sources/Wattcher/ProcessTerminator.swift` | Policy first; identity is revalidated before signaling |
| Change menu UX | `Sources/Wattcher/MenuController.swift` | Pure AppKit `NSStatusItem` and `NSMenu` |
| Change review dialogs | `Sources/Wattcher/ReviewPresenter.swift` | Keep/quit/ignore disclosure and stale-review messaging |
| Change scheduling | `Sources/Wattcher/AuditScheduler.swift` | Best-effort `NSBackgroundActivityScheduler` |
| Change notification actions | `Sources/Wattcher/NotificationCoordinator.swift` | Review or ignore; never direct termination |
| Trace the full scan flow | `Sources/Wattcher/MonitorCoordinator.swift` | Composition and persisted-state boundary |

## CODE MAP

SourceKit document symbols were available; codegraph reference counts were unavailable for this new repository.

| Symbol | Type | Location | Refs | Role |
|---|---|---|---:|---|
| `MonitorCoordinator` | class | `Sources/Wattcher/MonitorCoordinator.swift:6` | n/a | Owns scan-to-menu/notification flow |
| `SystemScanner` | struct | `Sources/WattcherCore/SystemScanner.swift:29` | n/a | Produces typed live snapshots |
| `RulesEngine` | struct | `Sources/WattcherCore/RulesEngine.swift:51` | n/a | Evaluates EWMA and structural rules |
| `TerminationPolicy` | enum | `Sources/WattcherCore/TerminationPolicy.swift` | n/a | Blocks unsafe targets |
| `MenuController` | class | `Sources/Wattcher/MenuController.swift:25` | n/a | Renders the menu-bar surface |
| `StateStore` | class | `Sources/WattcherCore/StateStore.swift` | n/a | Persists bounded local state |

## CONVENTIONS

- Swift 6 language mode; concurrency crossings use `Sendable`, async functions, or `@MainActor`.
- `WattcherCore` has no AppKit dependency. System data enters as typed value models.
- UI, `UserDefaults`, notifications, ServiceManagement, and process actions stay on the main actor.
- Clean checks are silent; menu timestamps still update.
- “Battery impact” is always labeled as an estimate, never watts or Activity Monitor parity.
- Process ignore rules use executable path; running baselines use PID, start time, and canonical path.
- Build artifacts stay under `.build/`; no Xcode project is required.

## ANTI-PATTERNS (THIS PROJECT)

- Never add automatic termination, notification-triggered termination, or `SIGKILL` for monitored processes. Collector timeout enforcement is separate.
- Never weaken PID/UID/path revalidation or protected-process checks.
- Never add private frameworks, `powermetrics` privilege escalation, a helper daemon, or admin prompts for v1.
- Never attribute RAM usage to a port; the owning process consumes RAM.
- Never send process names, paths, ports, or baselines to a cloud model by default.
- Never replace the energy-aware audit scheduler with frequent resident polling.
- Never scan LaunchAgent directories once per process; load them once per audit.

## COMMANDS

```bash
swift build
swift test
.build/debug/Wattcher --help
.build/debug/Wattcher --scan-once
./scripts/build-app.sh
zsh -n scripts/release-app.sh
open .build/Wattcher.app
```

## NOTES

- The app is deliberately unsandboxed for process/socket visibility and signals only current-user processes.
- Launch at Login is most reliable for a signed app installed in `/Applications`.
- `NSBackgroundActivityScheduler` intervals are approximate and may be deferred around sleep or power policy.
- A strict 5–10 MB RSS promise is not credible for modern native macOS UI. Measure the release app and report observed RSS.
