# WATTCHER APP KNOWLEDGE

## OVERVIEW

Main-actor AppKit application target. It composes the core scanner/rules with the status menu, energy-aware scheduler, local notifications, launch-at-login control, review dialogs, and final process signal.

## WHERE TO LOOK

| Concern | File | Contract |
|---|---|---|
| Process entry and diagnostic CLI | `main.swift` | `--help`, `--scan-once`, or accessory app |
| App lifetime | `AppDelegate.swift` | Own one `MonitorCoordinator` |
| Full audit orchestration | `MonitorCoordinator.swift` | One pipeline for scheduled and manual scans |
| Menu rendering | `MenuController.swift` | Status, activity, actionable listening owners, findings |
| Menu state and actions | `MenuViewState.swift` | Presentation-only values and callbacks |
| Review dialogs | `ReviewPresenter.swift` | Explicit keep/quit/ignore choices and persistent-ignore disclosure |
| Background cadence | `AuditScheduler.swift` | Approximate repeating audits; no busy timer |
| Notification delivery | `NotificationCoordinator.swift` | Review and ignore actions only |
| Signal execution | `ProcessTerminator.swift` | Revalidate identity, then `SIGTERM` |

## CONVENTIONS

- All AppKit and mutable presentation state is `@MainActor`.
- Keep system collection out of the main thread; `SystemScanner` owns its utility tasks.
- Every menu interval comes from `MonitorInterval.allCases`.
- Notification findings are cooldown-filtered before delivery.
- The review alert orders actions as Keep Running, Quit Process, Ignore Future Alerts; persistent ignores must have an undo surface.
- Launch-at-login failures remain visible in menu state instead of being swallowed.

## ANTI-PATTERNS

- Do not put quit semantics directly in a notification action.
- Do not call `kill` before exact PID/UID/executable revalidation.
- Do not add a Dock window or resident web view without revisiting the footprint goal.
- Do not schedule a second scan while one is in progress.
- Do not claim the next-check timestamp is exact.
- Do not add retry loops for a launchd-managed process that restarts.

## MANUAL SURFACE

Build the `.app`, launch it, open the bolt status item, run Check Now, change an interval, and inspect a controlled finding before accepting changes to this target.
