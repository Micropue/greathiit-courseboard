import CourseBoardCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    let closeAction: () -> Void

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                HeaderView(model: model)

                Divider()
                    .opacity(0.35)

                Group {
                    if model.isShowingSettings {
                        SettingsView(model: model)
                    } else if !model.hasJWT {
                        AuthenticationView(model: model)
                    } else {
                        ScheduleView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !model.isShowingSettings {
                    StatusBarView(model: model)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 746)
        .background(Color.clear)
        .tint(model.accentColor)
        .environment(\.appAccent, model.accentColor)
        .onExitCommand(perform: closeAction)
        .task {
            model.refreshIfNeeded()
        }
        .animation(.easeInOut(duration: 0.2), value: model.isShowingSettings)
        .animation(.easeInOut(duration: 0.2), value: model.hasJWT)
        .animation(.easeInOut(duration: 0.18), value: model.accentTheme)
    }
}

private struct HeaderView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            CourseBoardMark(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("哈信息课程表")
                    .font(.system(size: 16.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(model.isShowingSettings ? "设置与访问配置" : "哈尔滨信息工程学院")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    IconButton(
                        systemName: model.isLoading
                            ? "arrow.triangle.2.circlepath"
                            : "arrow.clockwise",
                        help: "刷新课程表"
                    ) {
                        model.refresh()
                    }

                    IconButton(
                        systemName: "gearshape",
                        help: "设置",
                        isActive: model.isShowingSettings
                    ) {
                        if model.isShowingSettings {
                            model.cancelHotKeyRecording()
                        }
                        model.isShowingSettings.toggle()
                    }
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.top, 11)
        .padding(.bottom, 9)
    }
}

private struct ScheduleView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                WeekNavigatorView(model: model)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(scheduleTitle)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    Text(scheduleSubtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            if let message = model.errorMessage {
                ErrorBannerView(
                    message: message,
                    requiresJWT: model.errorRequiresJWT,
                    retry: model.refresh,
                    openSettings: { model.isShowingSettings = true }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            Group {
                if model.isLoading && model.courses.isEmpty {
                    LoadingView()
                } else if model.courses.isEmpty,
                          model.errorMessage != nil {
                    EmptyScheduleView(
                        title: "还没有拿到课程",
                        message: "检查网络或 JWT 后重试。",
                        systemName: "wifi.exclamationmark"
                    )
                } else if model.courses.isEmpty {
                    EmptyScheduleView(
                        title: "本周暂时没有课程",
                        message: "可以切换到其他教学周看看。",
                        systemName: "cup.and.saucer"
                    )
                } else {
                    ScheduleBoardView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var scheduleTitle: String {
        "整周课程"
    }

    private var scheduleSubtitle: String {
        "第 \(model.week) 周 · \(model.courses.count) 门课程"
    }
}

private struct TokenField: View {
    @Binding var text: String
    let prompt: String
    var isCompact = false
    let onSubmit: () -> Void
    let paste: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: isCompact ? 11.5 : 13, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            SecureField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(
                    .system(
                        size: isCompact ? 12 : 13,
                        design: .monospaced
                    )
                )
                .onSubmit(onSubmit)

            Button(action: paste) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: isCompact ? 27 : 31, height: isCompact ? 27 : 31)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(
                                Color.primary.opacity(0.06),
                                lineWidth: 1
                            )
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .help("从剪贴板粘贴")
            .accessibilityLabel("从剪贴板粘贴")
        }
        .padding(.leading, isCompact ? 12 : 15)
        .padding(.trailing, isCompact ? 6 : 8)
        .padding(.vertical, isCompact ? 5 : 7)
        .glassEffect(
            .regular,
            in: RoundedRectangle(
                cornerRadius: isCompact ? 11 : 14,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: isCompact ? 11 : 14,
                style: .continuous
            )
            .strokeBorder(Color.primary.opacity(0.075), lineWidth: 1)
        }
    }
}

private struct AuthenticationView: View {
    @ObservedObject var model: AppModel

    @Environment(\.appAccent) private var accent

    private var canConnect: Bool {
        !model.jwtDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 27, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
                    .frame(width: 68, height: 68)
                    .glassEffect(
                        Glass.regular
                            .tint(accent.opacity(0.10))
                            .interactive(),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                Color.primary.opacity(0.055),
                                lineWidth: 1
                            )
                    }

                VStack(spacing: 7) {
                    Text("连接你的课程表")
                        .font(.title2.weight(.bold))
                    Text("粘贴“获取课程表”快捷指令使用的 JWT")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    TokenField(
                        text: $model.jwtDraft,
                        prompt: "在此粘贴 JWT",
                        onSubmit: {
                            if canConnect {
                                model.saveJWT()
                            }
                        },
                        paste: model.pasteJWTFromClipboard
                    )

                    Button {
                        model.saveJWT()
                    } label: {
                        HStack(spacing: 7) {
                            if model.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("连接")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(accent)
                    .controlSize(.large)
                    .disabled(!canConnect)
                    .opacity(canConnect ? 1 : 0.5)
                }
                .frame(maxWidth: 500)

                if let message = model.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.danger)
                        .frame(maxWidth: 500, alignment: .leading)
                }

                HStack(spacing: 18) {
                    Label("仅保存在本机钥匙串", systemImage: "lock.shield")
                    Label("不会上传到第三方", systemImage: "checkmark.shield")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(24)
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel

    @Environment(\.appAccent) private var accent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("设置")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("快捷键、凭据与本地数据")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("完成") {
                        model.cancelHotKeyRecording()
                        model.isShowingSettings = false
                    }
                    .buttonStyle(.neutralGlass)
                }
                .padding(.bottom, 3)

                SettingsCard(
                    systemName: "command",
                    title: "全局快捷键",
                    detail: "在任何 App 中都可以呼出课程表"
                ) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 11) {
                            Text(
                                model.hasRegisteredHotKey
                                    ? model.hotKeySpec.title
                                    : "未设置"
                            )
                            .font(
                                .system(
                                    size: 16,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .monospaced()
                            .frame(minWidth: 76)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .glassEffect(
                                model.isRecordingHotKey
                                    ? Glass.regular
                                        .tint(accent.opacity(0.14))
                                        .interactive()
                                    : Glass.regular,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        Color.primary.opacity(0.07),
                                        lineWidth: 1
                                    )
                            }

                            if model.isRecordingHotKey {
                                Label(
                                    "请按下新的组合键… Esc 取消",
                                    systemImage: "dot.radiowaves.left.and.right"
                                )
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(accent)
                            } else {
                                Text("再次按下即可收起，设置会自动保存。")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            if model.isRecordingHotKey {
                                Button("取消") {
                                    model.cancelHotKeyRecording()
                                }
                                .buttonStyle(.neutralGlass)
                            } else {
                                Button("录制新快捷键") {
                                    model.beginHotKeyRecording()
                                }
                                .buttonStyle(.neutralGlass)
                            }
                        }

                        Text("快捷键至少需要包含 Control、Option 或 Command。")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)

                        if let message = model.hotKeyError {
                            Label(
                                message,
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.danger)
                        }
                    }
                    .background {
                        ShortcutRecorderView(
                            isRecording: model.isRecordingHotKey,
                            onCapture: model.assignHotKey,
                            onCancel: model.cancelHotKeyRecording,
                            onInvalid: model.reportInvalidHotKey
                        )
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                    }
                }

                SettingsCard(
                    systemName: "paintpalette.fill",
                    title: "主题色",
                    detail: "强调色会立即应用到课程表与控件"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(
                                    .flexible(),
                                    spacing: 7
                                ),
                                count: 5
                            ),
                            spacing: 7
                        ) {
                            ForEach(AppAccentTheme.allCases) { theme in
                                ThemeColorButton(
                                    theme: theme,
                                    isSelected: model.accentTheme == theme
                                ) {
                                    model.accentTheme = theme
                                }
                            }
                        }

                        Text("选择“系统”会跟随 macOS 设置中的强调色。")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                SettingsCard(
                    systemName: "power",
                    title: "开机自启",
                    detail: "登录 macOS 后自动驻留在菜单栏"
                ) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.launchAtLoginStatusText)
                                    .font(.system(size: 12, weight: .semibold))
                                Text("快捷键可直接呼出，课程表无需手动启动。")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 10)

                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { model.launchAtLoginEnabled },
                                    set: { model.setLaunchAtLoginEnabled($0) }
                                )
                            )
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .tint(accent)
                        }

                        if model.launchAtLoginNeedsApproval {
                            Button("打开登录项设置") {
                                model.openLoginItemsSettings()
                            }
                            .buttonStyle(.neutralGlass)
                        }

                        if let message = model.launchAtLoginError {
                            Label(
                                message,
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.danger)
                        }
                    }
                }

                SettingsCard(
                    systemName: "key.fill",
                    title: "访问令牌",
                    detail: model.hasJWT
                        ? "JWT 已保存在 macOS 钥匙串"
                        : "尚未保存 JWT"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        TokenField(
                            text: $model.jwtDraft,
                            prompt: model.hasJWT
                                ? "输入新 JWT 可替换当前令牌"
                                : "粘贴 JWT",
                            isCompact: true,
                            onSubmit: model.saveJWT,
                            paste: model.pasteJWTFromClipboard
                        )

                        HStack(spacing: 9) {
                            Button(model.hasJWT ? "替换并刷新" : "保存并刷新") {
                                model.saveJWT()
                            }
                            .buttonStyle(.glassProminent)
                            .tint(accent)
                            .disabled(
                                model.jwtDraft.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty
                            )

                            Spacer()

                            if model.hasJWT {
                                Button("清除凭据", role: .destructive) {
                                    model.clearJWT()
                                    model.isShowingSettings = false
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(AppTheme.danger)
                            }
                        }

                        if let message = model.errorMessage {
                            Text(message)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.danger)
                        }
                    }
                }

                SettingsCard(
                    systemName: "externaldrive.fill.badge.checkmark",
                    title: "本地数据",
                    detail: "课程请求与缓存"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsRow(
                            title: "接口",
                            value: "api.greathiit.com"
                        )
                        SettingsRow(
                            title: "缓存",
                            value: "Application Support / CourseBoard"
                        )
                        SettingsRow(
                            title: "最近同步",
                            value: model.lastUpdated.map(Self.dateFormatter.string)
                                ?? "尚未同步"
                        )
                    }
                }
            }
            .padding(22)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private struct ThemeColorButton: View {
    let theme: AppAccentTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(theme.color)
                    .frame(width: 14, height: 14)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(0.38),
                                lineWidth: 0.75
                            )
                    }

                Text(theme.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)

                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Capsule())
            .glassEffect(
                isSelected
                    ? .regular
                        .tint(theme.color.opacity(0.12))
                        .interactive()
                    : .regular.interactive(),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? theme.color.opacity(0.48)
                            : Color.primary.opacity(0.055),
                        lineWidth: isSelected ? 1.25 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .help("使用\(theme.title)作为主题色")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SettingsCard<Content: View>: View {
    let systemName: String
    let title: String
    let detail: String
    @ViewBuilder let content: () -> Content

    @Environment(\.appAccent) private var accent

    init(
        systemName: String,
        title: String,
        detail: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.systemName = systemName
        self.title = title
        self.detail = detail
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .glassEffect(.regular, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(
                                Color.primary.opacity(0.055),
                                lineWidth: 1
                            )
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(15)
        .glassCard(cornerRadius: 16)
    }
}

private struct SettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.system(size: 11.5, weight: .medium))
    }
}

private struct ErrorBannerView: View {
    let message: String
    let requiresJWT: Bool
    let retry: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.danger)

            Text(message)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(2)

            Spacer(minLength: 12)

            Button(requiresJWT ? "更新 JWT" : "重试") {
                if requiresJWT {
                    openSettings()
                } else {
                    retry()
                }
            }
            .buttonStyle(.neutralGlass)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            AppTheme.danger.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }
}

private struct LoadingView: View {
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(accent)
            Text("正在同步课程表…")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyScheduleView: View {
    let title: String
    let message: String
    let systemName: String

    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(accent.opacity(0.75))
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(message)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StatusBarView: View {
    @ObservedObject var model: AppModel

    private var syncText: String {
        if model.isLoading {
            return "正在同步"
        }
        guard let lastUpdated = model.lastUpdated else {
            return "等待同步"
        }
        return "更新于 \(Self.timeFormatter.string(from: lastUpdated))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Label(
                model.hasRegisteredHotKey
                    ? "\(model.hotKeySpec.title) 呼出 / 收起"
                    : "全局快捷键不可用",
                systemImage: model.hasRegisteredHotKey
                    ? "keyboard"
                    : "keyboard.badge.exclamationmark"
            )

            Text("·")
                .opacity(0.35)

            Text(syncText)

            Spacer()

            if model.hasJWT {
                Label("JWT 已存入钥匙串", systemImage: "lock.fill")
            } else {
                Label("尚未配置 JWT", systemImage: "key.slash")
            }
        }
        .font(.system(size: 9.5, weight: .medium))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.clear)
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.18)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
