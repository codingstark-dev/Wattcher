import Carbon.HIToolbox
import Foundation

enum GlobalShortcut: String, CaseIterable, Sendable {
    case controlOptionW
    case controlOptionP
    case controlOptionK
    case controlOptionCommandW

    var title: String {
        switch self {
        case .controlOptionW: "⌃⌥W"
        case .controlOptionP: "⌃⌥P"
        case .controlOptionK: "⌃⌥K"
        case .controlOptionCommandW: "⌃⌥⌘W"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .controlOptionW, .controlOptionCommandW: 13
        case .controlOptionP: 35
        case .controlOptionK: 40
        }
    }

    var modifiers: UInt32 {
        let base = UInt32(controlKey | optionKey)
        return self == .controlOptionCommandW ? base | UInt32(cmdKey) : base
    }
}

@MainActor
final class GlobalHotKeyController {
    var onInvoke: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<GlobalHotKeyController>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                Task { @MainActor in controller.onInvoke?() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    func apply(enabled: Bool, shortcut: GlobalShortcut) -> String {
        unregister()
        guard enabled else { return "Global shortcut is off" }
        let identifier = EventHotKeyID(signature: OSType(0x5754_5452), id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard status == noErr else {
            return "\(shortcut.title) is already used by another app"
        }
        return "Global shortcut: \(shortcut.title)"
    }

    func stop() {
        unregister()
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }

    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }
}
