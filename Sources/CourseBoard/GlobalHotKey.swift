import AppKit
import Carbon
import Foundation

final class GlobalHotKey {
    struct Spec: Codable, Hashable {
        let keyCode: UInt32
        let modifiers: UInt32

        init(keyCode: UInt32, modifiers: UInt32) {
            self.keyCode = keyCode
            self.modifiers = modifiers & Self.supportedModifiers
        }

        init(event: NSEvent) {
            self.init(
                keyCode: UInt32(event.keyCode),
                modifiers: Self.carbonModifiers(from: event.modifierFlags)
            )
        }

        var title: String {
            Self.modifierSymbols(for: modifiers) + Self.keyName(for: keyCode)
        }

        var hasRequiredModifier: Bool {
            let required = UInt32(controlKey | optionKey | cmdKey)
            return modifiers & required != 0
        }

        static let preferred = Spec(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey)
        )

        static let fallback = Spec(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(controlKey | optionKey)
        )

        static func carbonModifiers(
            from flags: NSEvent.ModifierFlags
        ) -> UInt32 {
            let flags = flags.intersection(.deviceIndependentFlagsMask)
            var modifiers: UInt32 = 0

            if flags.contains(.control) {
                modifiers |= UInt32(controlKey)
            }
            if flags.contains(.option) {
                modifiers |= UInt32(optionKey)
            }
            if flags.contains(.shift) {
                modifiers |= UInt32(shiftKey)
            }
            if flags.contains(.command) {
                modifiers |= UInt32(cmdKey)
            }

            return modifiers
        }

        private static let supportedModifiers = UInt32(
            controlKey | optionKey | shiftKey | cmdKey
        )

        private static func modifierSymbols(for modifiers: UInt32) -> String {
            var symbols = ""
            if modifiers & UInt32(controlKey) != 0 {
                symbols += "⌃"
            }
            if modifiers & UInt32(optionKey) != 0 {
                symbols += "⌥"
            }
            if modifiers & UInt32(shiftKey) != 0 {
                symbols += "⇧"
            }
            if modifiers & UInt32(cmdKey) != 0 {
                symbols += "⌘"
            }
            return symbols
        }

        private static func keyName(for keyCode: UInt32) -> String {
            keyNames[Int(keyCode)] ?? "Key \(keyCode)"
        }

        private static let keyNames: [Int: String] = [
            Int(kVK_ANSI_A): "A",
            Int(kVK_ANSI_B): "B",
            Int(kVK_ANSI_C): "C",
            Int(kVK_ANSI_D): "D",
            Int(kVK_ANSI_E): "E",
            Int(kVK_ANSI_F): "F",
            Int(kVK_ANSI_G): "G",
            Int(kVK_ANSI_H): "H",
            Int(kVK_ANSI_I): "I",
            Int(kVK_ANSI_J): "J",
            Int(kVK_ANSI_K): "K",
            Int(kVK_ANSI_L): "L",
            Int(kVK_ANSI_M): "M",
            Int(kVK_ANSI_N): "N",
            Int(kVK_ANSI_O): "O",
            Int(kVK_ANSI_P): "P",
            Int(kVK_ANSI_Q): "Q",
            Int(kVK_ANSI_R): "R",
            Int(kVK_ANSI_S): "S",
            Int(kVK_ANSI_T): "T",
            Int(kVK_ANSI_U): "U",
            Int(kVK_ANSI_V): "V",
            Int(kVK_ANSI_W): "W",
            Int(kVK_ANSI_X): "X",
            Int(kVK_ANSI_Y): "Y",
            Int(kVK_ANSI_Z): "Z",
            Int(kVK_ANSI_0): "0",
            Int(kVK_ANSI_1): "1",
            Int(kVK_ANSI_2): "2",
            Int(kVK_ANSI_3): "3",
            Int(kVK_ANSI_4): "4",
            Int(kVK_ANSI_5): "5",
            Int(kVK_ANSI_6): "6",
            Int(kVK_ANSI_7): "7",
            Int(kVK_ANSI_8): "8",
            Int(kVK_ANSI_9): "9",
            Int(kVK_ANSI_Equal): "=",
            Int(kVK_ANSI_Minus): "-",
            Int(kVK_ANSI_RightBracket): "]",
            Int(kVK_ANSI_LeftBracket): "[",
            Int(kVK_ANSI_Quote): "'",
            Int(kVK_ANSI_Semicolon): ";",
            Int(kVK_ANSI_Backslash): "\\",
            Int(kVK_ANSI_Comma): ",",
            Int(kVK_ANSI_Slash): "/",
            Int(kVK_ANSI_Period): ".",
            Int(kVK_ANSI_Grave): "`",
            Int(kVK_Space): "Space",
            Int(kVK_Return): "↩",
            Int(kVK_Tab): "⇥",
            Int(kVK_Delete): "⌫",
            Int(kVK_ForwardDelete): "⌦",
            Int(kVK_Escape): "Esc",
            Int(kVK_LeftArrow): "←",
            Int(kVK_RightArrow): "→",
            Int(kVK_UpArrow): "↑",
            Int(kVK_DownArrow): "↓",
            Int(kVK_Home): "Home",
            Int(kVK_End): "End",
            Int(kVK_PageUp): "Page Up",
            Int(kVK_PageDown): "Page Down",
            Int(kVK_F1): "F1",
            Int(kVK_F2): "F2",
            Int(kVK_F3): "F3",
            Int(kVK_F4): "F4",
            Int(kVK_F5): "F5",
            Int(kVK_F6): "F6",
            Int(kVK_F7): "F7",
            Int(kVK_F8): "F8",
            Int(kVK_F9): "F9",
            Int(kVK_F10): "F10",
            Int(kVK_F11): "F11",
            Int(kVK_F12): "F12",
            Int(kVK_F13): "F13",
            Int(kVK_F14): "F14",
            Int(kVK_F15): "F15",
            Int(kVK_F16): "F16",
            Int(kVK_F17): "F17",
            Int(kVK_F18): "F18",
            Int(kVK_F19): "F19",
            Int(kVK_F20): "F20"
        ]
    }

    enum RegistrationError: LocalizedError {
        case eventHandler(OSStatus)
        case hotKey(OSStatus)

        var errorDescription: String? {
            switch self {
            case .eventHandler:
                return "无法创建全局快捷键事件处理器。"
            case .hotKey(let status):
                if status == OSStatus(eventHotKeyExistsErr) {
                    return "这个快捷键已被其他应用占用。"
                }
                return "系统拒绝注册这个快捷键（错误 \(status)）。"
            }
        }
    }

    static let defaultsKey = "CourseBoard.globalHotKey"

    private static let signature: OSType = 0x43524244

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private(set) var registeredSpec: Spec?
    var action: (() -> Void)?

    func installEventHandler() throws {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }
                let manager = Unmanaged<GlobalHotKey>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if result == noErr, hotKeyID.signature == OSType(0x43524244) {
                    manager.action?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            throw RegistrationError.eventHandler(status)
        }
    }

    func register(_ spec: Spec) throws {
        guard spec.hasRequiredModifier else {
            throw RegistrationError.hotKey(OSStatus(paramErr))
        }
        guard registeredSpec != spec else {
            return
        }

        unregisterHotKey()

        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            throw RegistrationError.hotKey(status)
        }

        hotKeyRef = reference
        registeredSpec = spec
    }

    func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        registeredSpec = nil
    }

    func uninstall() {
        unregisterHotKey()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregisterHotKey()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
