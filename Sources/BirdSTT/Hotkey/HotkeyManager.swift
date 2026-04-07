import Carbon
import Combine
import Foundation

/// Registers a system-wide hotkey using Carbon RegisterEventHotKey.
/// This is the most reliable global hotkey mechanism on macOS —
/// no Accessibility or Input Monitoring permissions required.
///
/// Default hotkey: Ctrl + Shift + B
final class HotkeyManager {
    let triggered = PassthroughSubject<Void, Never>()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private static let hotKeySignature: OSType = {
        // "BSTT" as a 4-byte OSType
        let b = UInt32(UnicodeScalar("B").value) << 24
        let s = UInt32(UnicodeScalar("S").value) << 16
        let t1 = UInt32(UnicodeScalar("T").value) << 8
        let t2 = UInt32(UnicodeScalar("T").value)
        return OSType(b | s | t1 | t2)
    }()

    func start() -> Bool {
        // Install Carbon event handler for hot key events
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        guard status == noErr else {
            print("[HotkeyManager] Failed to install event handler: \(status)")
            return false
        }

        // Register Ctrl + Shift + B
        let hotKeyID = EventHotKeyID(
            signature: HotkeyManager.hotKeySignature,
            id: 1
        )

        let regStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_B),
            UInt32(controlKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard regStatus == noErr else {
            print("[HotkeyManager] Failed to register hotkey: \(regStatus)")
            return false
        }

        print("[HotkeyManager] Started — press Ctrl+Shift+B to trigger")
        return true
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    fileprivate func handleHotKey() {
        print("[HotkeyManager] Ctrl+Shift+B triggered!")
        triggered.send()
    }
}

// Carbon event handler — must be a free C function
private func hotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotKey()
    return noErr
}
