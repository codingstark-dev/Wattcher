import AppKit
import XCTest
@testable import Wattcher

@MainActor
final class SettingsLayoutTests: XCTestCase {
    func testSettingsInteractiveControlsDoNotOverlap() {
        let controller = SettingsWindowController(
            actions: SettingsActions(
                setInterval: { _ in },
                toggleLaunchAtLogin: {},
                shortcutChanged: {},
                updatesChanged: {}
            ),
            preferences: AppPreferences(),
            updates: UpdateController()
        )
        guard let contentView = controller.window?.contentView else {
            return XCTFail("Settings window must have a content view")
        }

        contentView.layoutSubtreeIfNeeded()
        let controls = descendants(of: contentView).compactMap { view -> NSControl? in
            guard view is NSButton || view is NSPopUpButton else { return nil }
            return view as? NSControl
        }

        for (index, control) in controls.enumerated() {
            let frame = control.convert(control.bounds, to: contentView)
            XCTAssertTrue(
                contentView.bounds.contains(frame),
                "\(control) must remain inside the Settings window"
            )
            for other in controls.dropFirst(index + 1) {
                let otherFrame = other.convert(other.bounds, to: contentView)
                XCTAssertFalse(
                    frame.intersects(otherFrame),
                    "Settings controls must not overlap: \(control) and \(other)"
                )
            }
        }
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants)
    }
}
