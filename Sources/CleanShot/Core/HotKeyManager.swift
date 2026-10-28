import AppKit
import Carbon

/// Global HotKey Manager using Carbon Event Manager for system-wide shortcut interception.
@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: @MainActor () -> Void] = [:]

    private init() {
        installCarbonEventHandler()
    }

    // MARK: - Registration

    public func register(
        id: UInt32,
        keyCode: UInt32,
        modifiers: UInt32,
        action: @escaping @MainActor () -> Void
    ) {
        unregister(id: id)

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4E53), id: id) // 'CLNS'

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let validRef = hotKeyRef else {
            print("[HotKeyManager] Failed to register hotkey id \(id) with error: \(status)")
            return
        }

        hotKeyRefs[id] = validRef
        handlers[id] = action
    }

    public func unregister(id: UInt32) {
        guard let ref = hotKeyRefs.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(ref)
        handlers.removeValue(forKey: id)
    }

    // MARK: - Event Dispatch

    fileprivate func dispatchHotKey(id: UInt32) {
        guard let handler = handlers[id] else { return }
        handler()
    }

    // MARK: - Carbon Handler

    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, eventRef, _ -> OSStatus in
            guard let eventRef = eventRef else { return noErr }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else { return status }

            DispatchQueue.main.async {
                HotKeyManager.shared.dispatchHotKey(id: hotKeyID.id)
            }

            return noErr
        }

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        if status != noErr {
            print("[HotKeyManager] Failed to install Carbon event handler: \(status)")
        }
    }
}
