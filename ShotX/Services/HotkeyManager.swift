import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private enum Hotkey: UInt32 {
        case captureSelection = 1
        case captureFullScreen = 2
    }

    private let captureSelection: () -> Void
    private let captureFullScreen: () -> Void
    private var hotkeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?

    init(captureSelection: @escaping () -> Void, captureFullScreen: @escaping () -> Void) {
        self.captureSelection = captureSelection
        self.captureFullScreen = captureFullScreen
    }

    deinit {
        for ref in hotkeyRefs {
            if let ref {
                UnregisterEventHotKey(ref)
            }
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func start() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                guard status == noErr else { return status }

                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    manager.handleHotkey(id: hotkeyID.id)
                }

                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )

        register(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | shiftKey), id: .captureSelection)
        register(keyCode: UInt32(kVK_F13), modifiers: 0, id: .captureFullScreen)
    }

    private func register(keyCode: UInt32, modifiers: UInt32, id: Hotkey) {
        var hotkeyRef: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: Self.signature, id: id.rawValue)

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            hotkeyRefs.append(hotkeyRef)
        } else {
            NSLog("ShotX failed to register hotkey \(id.rawValue): \(status)")
        }
    }

    private func handleHotkey(id: UInt32) {
        switch Hotkey(rawValue: id) {
        case .captureSelection:
            captureSelection()
        case .captureFullScreen:
            captureFullScreen()
        case .none:
            break
        }
    }

    private static var signature: OSType {
        OSType(
            UInt32(Character("S").asciiValue!) << 24 |
            UInt32(Character("h").asciiValue!) << 16 |
            UInt32(Character("t").asciiValue!) << 8 |
            UInt32(Character("X").asciiValue!)
        )
    }
}
