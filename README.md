# Wattcher

Wattcher is a native macOS menu-bar utility that periodically checks which processes are using CPU and RAM and which processes own listening TCP ports. It learns a lightweight local baseline, reports explainable anomalies, and lets the user review, ignore, or gracefully quit a process.

Wattcher does not claim to measure true per-process wattage. macOS does not expose Activity Monitor's full energy-impact data through a public unprivileged API, so Wattcher labels CPU and memory anomalies as estimated battery impact.

## Install

Download the latest `.dmg` from [GitHub Releases](https://github.com/codingstark-dev/Wattcher/releases/latest), double-click it, then drag `Wattcher.app` onto the Applications shortcut. Eject the installer after the copy finishes.

## What it does

- Runs an audit about every 10 minutes, 15 minutes, 20 minutes, 1 hour, 3 hours, or 8 hours.
- Provides a `Check Now` menu action.
- Reads battery percentage and power source with `pmset`.
- Enumerates current-user processes with `ps`, then reads canonical path, start time, cumulative CPU, resident memory, and wakeups with public `libproc` APIs.
- Maps listening TCP ports to their owning processes with machine-readable `lsof` output.
- Shows a searchable overview with development-only or all-listener filtering, endpoints, CPU, RAM, estimated impact, origin, and path.
- Opens local ports in the browser; copies endpoints; opens Terminal at the executable directory; and reveals executables in Finder.
- Supports safe per-process review and confirmed bulk quit with identity revalidation before every signal.
- Classifies foreground apps, LaunchAgents, LaunchDaemons, user processes, and system processes.
- Warms a baseline before alerting and requires two consecutive high samples for CPU or memory findings.
- Flags a newly exposed non-loopback listening port after warm-up.
- Sends local notifications only for findings, with a one-hour-or-longer cooldown.
- Requires an explicit confirmation before sending `SIGTERM`; ignored executables are listed by count and can be reset from the menu.
- Revalidates PID, user, canonical executable path, and process start time immediately before termination.
- Refuses to terminate system, other-user, self, PID 0/1, and other protected processes.
- Keeps all process and port telemetry on the Mac. Up to 50 notification-review records persist locally for at most 24 hours; there is no AI or cloud dependency.
- Includes signed in-app updates with automatic check/download controls powered by Sparkle.

## Build and run

Requirements: macOS 14 or newer and Xcode 16 or newer.

```bash
swift test
./scripts/build-app.sh
open .build/Wattcher.app
```

The release bundle is ad-hoc signed for local development. For a notarized distribution build, set `WATTCHER_SIGNING_IDENTITY` and `WATTCHER_NOTARY_PROFILE`, then run `./scripts/release-app.sh`. For normal launch-at-login behavior, copy the signed app to `/Applications`.

Build a Finder installer image with Wattcher and an Applications shortcut:

```bash
./scripts/build-dmg.sh
open .build/Wattcher-*.dmg
```

## Publishing updates

Wattcher uses a signed Sparkle appcast. Increment `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`, then prepare a notarized update:

```bash
WATTCHER_SIGNING_IDENTITY="Developer ID Application: …" \
WATTCHER_NOTARY_PROFILE="notary-profile" \
./scripts/prepare-update.sh
```

Create a GitHub release whose tag is `v<version>`, upload the printed `Wattcher-<version>.zip`, then commit and publish the updated `appcast.xml`. Existing installs check that HTTPS feed automatically and verify every archive with the private Sparkle key stored in the maintainer's Keychain. Never commit or upload the private key.

## Project

Wattcher is open-source software by [codingstark-dev](https://github.com/codingstark-dev).

The executable also exposes a diagnostic surface:

```bash
.build/debug/Wattcher --help
.build/debug/Wattcher --scan-once
```

## How findings work

Wattcher uses per-running-process baselines keyed by PID, start time, and canonical executable path. Baselines are exponentially weighted and pruned when a process exits.

- CPU: at least 8% CPU, at least 3x baseline, at least 5 percentage points over baseline, for two checks.
- Memory: at least 512 MB RSS, at least 1.5x baseline, at least 256 MB over baseline, for two checks.
- Port: a new listening TCP endpoint bound beyond loopback after the process has a warm baseline.

The thresholds intentionally favor fewer alerts. A finding is evidence for review, not proof that a process is malicious or wasteful.

## Scheduling semantics

The menu says “about every” because `NSBackgroundActivityScheduler` is energy-aware and macOS may defer work around sleep, thermal pressure, or power policy. Wattcher remains a small menu-bar process and runs one shared scan pipeline for both scheduled and manual checks.

## Distribution and permissions

Wattcher is unsandboxed because a process-inspection utility needs to enumerate listening sockets and signal user-owned processes. It does not install a privileged helper and never requests administrator access. This design targets notarized Developer ID distribution rather than the Mac App Store sandbox.

Wattcher is a user utility, not an anti-malware boundary. Another process already running as the same macOS user can modify that user's preferences or interfere with inspection. Wattcher limits its own persistence and revalidates a target immediately before signaling, but it does not defend against a compromised user account.

Notification permission is requested on first launch. Launch at Login uses `SMAppService` and may require the built app to reside in `/Applications`.

## Known limits

- CPU percentage is a process activity proxy, not electrical power in watts.
- Listening TCP ports are reported; UDP activity and outbound-only connections are not part of v1.
- Processes outside the current user's visibility may be absent or incomplete.
- A launchd-managed process may relaunch after `SIGTERM`; Wattcher reports that possibility rather than repeatedly killing it.
- A stuck fixed-path collector command is terminated after ten seconds and force-stopped after a one-second grace period. This never applies to a process selected from Wattcher's review UI.
- Modern Swift/AppKit apps do not realistically fit a strict 5–10 MB resident-memory budget. Measure the release build on the target Mac; Wattcher was observed around 53 MB RSS after launch and up to roughly 80 MB after opening menus and dialogs on the development machine.

## Project map

- `Sources/WattcherCore`: models, system collection, launch-origin classification, persisted state, rules, and termination policy.
- `Sources/Wattcher`: AppKit menu, scheduler, notifications, launch-at-login, review dialogs, and termination execution.
- `Tests/WattcherCoreTests`: deterministic parser, policy, interval, and rules coverage.
- `Resources/Info.plist`: agent-style application bundle metadata.
- `scripts/build-app.sh`: release bundle assembly and ad-hoc signing.
- `scripts/build-dmg.sh`: Finder disk image with an Applications shortcut.
- `scripts/release-app.sh`: Developer ID signing, notarization, stapling, and Gatekeeper verification.
