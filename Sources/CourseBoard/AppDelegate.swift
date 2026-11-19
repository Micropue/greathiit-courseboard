import AppKit
import Carbon
import Combine
import CourseBoardCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private let hotKey = GlobalHotKey()
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var settingsMenuItem: NSMenuItem?
    private var refreshMenuItem: NSMenuItem?
    private var needsInitialPresentation = false
    private var suspendedHotKeySpec: GlobalHotKey.Spec?
    private var deactivationObserver: NSObjectProtocol?

    private let panelAspectRatio: CGFloat = 9.0 / 16.0
    private let minimumPanelWidth: CGFloat = 420
    private let panelScreenInset: CGFloat = 16

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureWindow()
        configureStatusItem()
        configureHotKey()

        needsInitialPresentation =
            !ProcessInfo.processInfo.arguments.contains("--background")
            && !wasLaunchedAtLogin
        if needsInitialPresentation {
            scheduleInitialPresentation()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showPanel()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.uninstall()
        if let deactivationObserver {
            NotificationCenter.default.removeObserver(deactivationObserver)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    private var wasLaunchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            return LaunchAtLoginManager.isOn
        }
        guard event.eventID == AEEventID(kAEOpenApplication) else {
            return false
        }
        return event.attributeDescriptor(
            forKeyword: AEKeyword(keyAELaunchedAsLogInItem)
        ) != nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePanel()
        return false
    }

    private func configureHotKey() {
        hotKey.action = { [weak self] in
            self?.togglePanel()
        }

        do {
            try hotKey.installEventHandler()
        } catch {
            model.reportHotKeyFailure(error.localizedDescription)
            rebuildStatusMenu()
            return
        }

        let savedSpec = UserDefaults.standard
            .data(forKey: GlobalHotKey.defaultsKey)
            .flatMap {
                try? JSONDecoder().decode(
                    GlobalHotKey.Spec.self,
                    from: $0
                )
            }

        var candidates: [GlobalHotKey.Spec] = []
        if let savedSpec {
            candidates.append(savedSpec)
        }
        for spec in [GlobalHotKey.Spec.preferred, .fallback]
        where !candidates.contains(spec) {
            candidates.append(spec)
        }

        var registeredSpec: GlobalHotKey.Spec?
        for spec in candidates {
            do {
                try hotKey.register(spec)
                registeredSpec = spec
                break
            } catch {
                continue
            }
        }

        if let registeredSpec {
            let notice: String?
            if let savedSpec, savedSpec != registeredSpec {
                notice = "已保存的 \(savedSpec.title) 被占用，本次使用 \(registeredSpec.title)。"
            } else {
                notice = nil
            }
            model.setRegisteredHotKey(registeredSpec, notice: notice)
        } else {
            model.reportHotKeyFailure(
                "没有可用的全局快捷键，请从菜单栏或设置中重新指定。"
            )
        }

        model.onHotKeyChange = { [weak self] spec in
            self?.replaceHotKey(with: spec)
        }
        model.onBeginHotKeyRecording = { [weak self] in
            self?.suspendCurrentHotKey()
        }
        model.onCancelHotKeyRecording = { [weak self] in
            self?.restoreSuspendedHotKey()
        }

        rebuildStatusMenu()
    }

    private func suspendCurrentHotKey() {
        guard suspendedHotKeySpec == nil else {
            return
        }
        suspendedHotKeySpec = hotKey.registeredSpec
        hotKey.unregisterHotKey()
        rebuildStatusMenu()
    }

    private func restoreSuspendedHotKey() {
        guard let spec = suspendedHotKeySpec else {
            rebuildStatusMenu()
            return
        }
        suspendedHotKeySpec = nil
        do {
            try hotKey.register(spec)
            model.setRegisteredHotKey(spec)
        } catch {
            model.reportHotKeyFailure(
                "无法恢复 \(spec.title)：\(error.localizedDescription)"
            )
        }
        rebuildStatusMenu()
    }

    private func replaceHotKey(with spec: GlobalHotKey.Spec) -> String? {
        let previous = suspendedHotKeySpec ?? hotKey.registeredSpec
        hotKey.unregisterHotKey()

        do {
            try hotKey.register(spec)
            suspendedHotKeySpec = nil
            if let data = try? JSONEncoder().encode(spec) {
                UserDefaults.standard.set(
                    data,
                    forKey: GlobalHotKey.defaultsKey
                )
            }
            rebuildStatusMenu()
            return nil
        } catch {
            hotKey.unregisterHotKey()
            if let previous {
                try? hotKey.register(previous)
            }
            rebuildStatusMenu()

            let fallbackText = previous.map {
                "已保留 \($0.title)。"
            } ?? "当前没有已注册的全局快捷键。"
            return "无法使用 \(spec.title)：\(error.localizedDescription) \(fallbackText)"
        }
    }

    private func scheduleInitialPresentation() {
        for delay in [0.5, 1.5, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.needsInitialPresentation else {
                    return
                }
                if self.panel?.isVisible != true {
                    self.showPanel()
                }
                if delay == 3.0 {
                    self.needsInitialPresentation = false
                }
            }
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        if let button = item.button {
            button.image = Self.makeStatusIcon()
            button.toolTip = "哈信息课程表"
        }
        statusItem = item
        rebuildStatusMenu()
    }

    private static func makeStatusIcon() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: 16,
            weight: .medium
        )
        let image = NSImage(
            systemSymbolName: "calendar.badge.clock",
            accessibilityDescription: "课程表"
        )?.withSymbolConfiguration(configuration) ?? NSImage(
            size: NSSize(width: 18, height: 18)
        )
        image.isTemplate = true
        image.accessibilityDescription = "课程表"
        return image
    }

    private func rebuildStatusMenu() {
        guard let statusItem else {
            return
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "显示课程表  \(hotKey.registeredSpec?.title ?? "")",
            action: #selector(openFromMenu),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        if hotKey.registeredSpec == nil {
            let warning = NSMenuItem(
                title: "全局快捷键不可用，请用上方菜单入口",
                action: nil,
                keyEquivalent: ""
            )
            warning.isEnabled = false
            menu.addItem(warning)
        }

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(
            title: "刷新课程表",
            action: #selector(refreshFromMenu),
            keyEquivalent: "r"
        )
        refreshItem.keyEquivalentModifierMask = [.command]
        refreshItem.target = self
        menu.addItem(refreshItem)
        refreshMenuItem = refreshItem

        let exportItem = NSMenuItem(
            title: "导出日历…",
            action: #selector(exportCalendarFromMenu),
            keyEquivalent: "e"
        )
        exportItem.keyEquivalentModifierMask = [.command]
        exportItem.target = self
        menu.addItem(exportItem)

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)
        settingsMenuItem = settingsItem

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出课程表",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.toolTip =
            "哈信息课程表  \(hotKey.registeredSpec?.title ?? "")"
    }

    private func configureWindow() {
        let rootView = ContentView(
            model: model,
            closeAction: { [weak self] in
                self?.hidePanel()
            }
        )

        let hostingController = NSHostingController(rootView: rootView)
        let initialSize = preferredPanelSize(
            in: screenForPresentation()?.visibleFrame
                ?? NSScreen.main?.visibleFrame
                ?? NSRect(
                    x: 0,
                    y: 0,
                    width: 900,
                    height: 1200
                )
        )
        let window = NSPanel(
            contentRect: NSRect(
                origin: .zero,
                size: initialSize
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "哈信息课程表"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentAspectRatio = NSSize(width: 9, height: 16)
        window.contentMinSize = minimumPanelSize
        window.contentViewController = hostingController
        window.delegate = self
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.level = .floating
        window.becomesKeyOnlyIfNeeded = false
        window.isExcludedFromWindowsMenu = true
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        window.standardWindowButton(.closeButton)?.isEnabled = true
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        panel = window
        positionPanelOnLeft(on: window, usePreferredSize: true)

        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak window] _ in
            guard let window, window.isVisible else {
                return
            }
            window.orderFrontRegardless()
        }
    }

    private func screenForPresentation() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main
    }

    private func positionPanelOnLeft(
        on window: NSWindow,
        usePreferredSize: Bool = false
    ) {
        let screen = screenForPresentation() ?? window.screen
        guard let visibleFrame = screen?.visibleFrame else {
            return
        }

        let size = usePreferredSize
            ? preferredPanelSize(in: visibleFrame)
            : aspectConstrainedSize(
                window.frame.size,
                in: visibleFrame
            )

        window.setFrame(
            NSRect(
                x: visibleFrame.minX + panelScreenInset,
                y: visibleFrame.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: window.isVisible
        )
    }

    private var minimumPanelSize: NSSize {
        NSSize(
            width: minimumPanelWidth,
            height: minimumPanelWidth / panelAspectRatio
        )
    }

    private func preferredPanelSize(in visibleFrame: NSRect) -> NSSize {
        NSSize(
            width: preferredPanelWidth(in: visibleFrame),
            height: preferredPanelHeight(in: visibleFrame)
        )
    }

    private func preferredPanelWidth(in visibleFrame: NSRect) -> CGFloat {
        let availableHeight = max(
            visibleFrame.height - panelScreenInset * 2,
            1
        )
        let availableWidth = max(
            visibleFrame.width - panelScreenInset * 2,
            1
        )
        return min(availableHeight * panelAspectRatio, availableWidth)
    }

    private func preferredPanelHeight(in visibleFrame: NSRect) -> CGFloat {
        preferredPanelWidth(in: visibleFrame) / panelAspectRatio
    }

    private func aspectConstrainedSize(
        _ proposedSize: NSSize,
        in visibleFrame: NSRect
    ) -> NSSize {
        let availableWidth = max(
            visibleFrame.width - panelScreenInset * 2,
            1
        )
        let availableHeight = max(
            visibleFrame.height - panelScreenInset * 2,
            1
        )
        var height = min(
            max(proposedSize.height, minimumPanelSize.height),
            availableHeight
        )
        var width = height * panelAspectRatio

        if width > availableWidth {
            width = availableWidth
            height = width / panelAspectRatio
        }

        return NSSize(width: width, height: height)
    }

    func togglePanel() {
        guard let panel else {
            return
        }
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let panel else {
            return
        }
        positionPanelOnLeft(on: panel)
        model.refreshIfStale()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        needsInitialPresentation = false
        if model.isRecordingHotKey {
            model.cancelHotKeyRecording()
        }
        panel?.orderOut(nil)
        model.isShowingSettings = false
    }

    @objc private func openFromMenu() {
        model.isShowingSettings = false
        showPanel()
    }

    @objc private func refreshFromMenu() {
        showPanel()
        model.refresh()
    }

    @objc private func exportCalendarFromMenu() {
        showPanel()
        model.presentICSExport()
    }

    @objc private func openSettingsFromMenu() {
        model.isShowingSettings = true
        showPanel()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
