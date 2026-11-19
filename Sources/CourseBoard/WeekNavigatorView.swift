import SwiftUI

struct WeekNavigatorView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                weekStepper

                Menu {
                    ForEach(TeachingCalendar.weeks, id: \.self) { week in
                        Button {
                            model.setWeek(week)
                        } label: {
                            if week == model.week {
                                Label(
                                    "第 \(week) 周",
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text("第 \(week) 周")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("第 \(model.week) 周")
                            .font(
                                .system(
                                    .callout,
                                    design: .rounded,
                                    weight: .semibold
                                )
                            )
                            .monospacedDigit()

                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .frame(
                        minWidth: 92,
                        minHeight: ScheduleControlMetrics.controlHeight
                    )
                    .padding(.horizontal, 3)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                Color.primary.opacity(0.055),
                                lineWidth: 1
                            )
                    }
                    .contentShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("选择教学周")
                .accessibilityLabel("选择教学周，当前第 \(model.week) 周")
            }
        }
    }

    private var weekStepper: some View {
        HStack(spacing: 0) {
            Button(action: model.previousWeek) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .frame(
                        width: 42,
                        height: ScheduleControlMetrics.controlHeight - 4
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(model.week <= 1)
            .help("上一周")
            .accessibilityLabel("上一周")

            Rectangle()
                .fill(Color.primary.opacity(0.11))
                .frame(width: 1, height: 15)

            Button(action: model.nextWeek) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .frame(
                        width: 42,
                        height: ScheduleControlMetrics.controlHeight - 4
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(model.week >= TeachingCalendar.weekCount)
            .help("下一周")
            .accessibilityLabel("下一周")
        }
        .padding(2)
        .glassEffect(.regular.interactive(), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    Color.primary.opacity(0.055),
                    lineWidth: 1
                )
        }
        .fixedSize()
        .help("切换到上一周或下一周")
    }
}
