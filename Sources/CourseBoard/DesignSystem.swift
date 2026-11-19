import AppKit
import SwiftUI

enum AppTheme {
    static let danger = Color(nsColor: .systemRed)
}

enum AppAccentTheme: String, CaseIterable, Identifiable {
    case system
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal
    case graphite

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system: "系统"
        case .blue: "蓝色"
        case .purple: "紫色"
        case .pink: "粉色"
        case .red: "红色"
        case .orange: "橙色"
        case .yellow: "黄色"
        case .green: "绿色"
        case .teal: "青色"
        case .graphite: "石墨"
        }
    }

    var color: Color {
        switch self {
        case .system: Color(nsColor: .controlAccentColor)
        case .blue: Color(nsColor: .systemBlue)
        case .purple: Color(nsColor: .systemPurple)
        case .pink: Color(nsColor: .systemPink)
        case .red: Color(nsColor: .systemRed)
        case .orange: Color(nsColor: .systemOrange)
        case .yellow: Color(nsColor: .systemYellow)
        case .green: Color(nsColor: .systemGreen)
        case .teal: Color(nsColor: .systemTeal)
        case .graphite: Color(nsColor: .systemGray)
        }
    }
}

private struct AppAccentEnvironmentKey: EnvironmentKey {
    static let defaultValue = Color(nsColor: .controlAccentColor)
}

extension EnvironmentValues {
    var appAccent: Color {
        get { self[AppAccentEnvironmentKey.self] }
        set { self[AppAccentEnvironmentKey.self] = newValue }
    }
}

enum ScheduleControlMetrics {
    static let controlHeight: CGFloat = 34
}

struct AmbientBackground: View {
    var body: some View {
        VisualEffectView(
            material: .underWindowBackground,
            blendingMode: .behindWindow
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct CourseBoardMark: View {
    var size: CGFloat = 42

    @Environment(\.appAccent) private var accent

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: size * 0.28,
            style: .continuous
        )

        Image(systemName: "calendar")
            .font(.system(size: size * 0.43, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .glassEffect(
                .regular.tint(accent.opacity(0.09)),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    Color.primary.opacity(0.06),
                    lineWidth: 1
                )
            }
        .accessibilityHidden(true)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular,
                in: RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .strokeBorder(Color.primary.opacity(0.065), lineWidth: 1)
            }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

struct NeutralGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .glassEffect(.regular.interactive(), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        Color.primary.opacity(0.065),
                        lineWidth: 1
                    )
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == NeutralGlassButtonStyle {
    static var neutralGlass: NeutralGlassButtonStyle {
        NeutralGlassButtonStyle()
    }
}

struct IconButton: View {
    let systemName: String
    let help: String
    var isActive = false
    let action: () -> Void

    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13.5, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    isActive ? accent : Color.primary
                )
                .frame(width: 36, height: 36)
                .contentShape(Circle())
                .glassEffect(
                    isActive
                        ? .regular
                            .tint(accent.opacity(0.12))
                            .interactive()
                        : .regular.interactive(),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.primary.opacity(0.055),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(PressableButtonStyle())
        .fixedSize()
        .help(help)
        .accessibilityLabel(help)
    }
}
