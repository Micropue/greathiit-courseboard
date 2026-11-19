import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    let isRecording: Bool
    let onCapture: (GlobalHotKey.Spec) -> Void
    let onCancel: () -> Void
    let onInvalid: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        update(view)
        return view
    }

    func updateNSView(
        _ nsView: ShortcutRecorderNSView,
        context: Context
    ) {
        update(nsView)
    }

    private func update(_ view: ShortcutRecorderNSView) {
        view.onCapture = onCapture
        view.onCancel = onCancel
        view.onInvalid = onInvalid
        view.setRecording(isRecording)
    }
}

final class ShortcutRecorderNSView: NSView {
    var onCapture: ((GlobalHotKey.Spec) -> Void)?
    var onCancel: (() -> Void)?
    var onInvalid: (() -> Void)?

    private var isRecording = false
    private var eventMonitor: Any?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    func setRecording(_ recording: Bool) {
        guard recording != isRecording else {
            return
        }
        isRecording = recording

        if recording {
            installEventMonitor()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRecording else {
                    return
                }
                self.window?.makeFirstResponder(self)
            }
        } else {
            removeEventMonitor()
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handle(event)
    }

    private func installEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            guard let self, self.isRecording else {
                return event
            }
            self.handle(event)
            return nil
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            onCancel?()
            return
        }

        let spec = GlobalHotKey.Spec(event: event)
        guard spec.hasRequiredModifier else {
            NSSound.beep()
            onInvalid?()
            return
        }

        onCapture?(spec)
    }

    deinit {
        removeEventMonitor()
    }
}
