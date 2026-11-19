import CourseBoardCore
import SwiftUI

struct ScheduleBoardView: View {
    @ObservedObject var model: AppModel

    private struct CourseSlotKey: Hashable {
        let weekday: Int
        let period: Int
    }

    private let timeRailWidth: CGFloat = 48
    private let columnSpacing: CGFloat = 1.5
    private let rowHeight: CGFloat = 100
    private let rowSpacing: CGFloat = 8
    private let boardPadding: CGFloat = 0
    private let headerHeight: CGFloat = 42

    private let displayedWeekdays = Array(1...7)

    private var displayedBlocks: [TeachingBlock] {
        TeachingBlock.displayBlocks(for: model.courses)
    }

    var body: some View {
        GeometryReader { geometry in
            let weekdays = displayedWeekdays
            let coursesByWeekday = Dictionary(
                grouping: model.courses,
                by: \.weekday
            )
            let coursesBySlot = Dictionary(
                grouping: model.courses
            ) { course in
                CourseSlotKey(
                    weekday: course.weekday,
                    period: course.period
                )
            }
            let availableWidth = max(
                geometry.size.width - boardPadding * 2,
                0
            )
            let gapsWidth = CGFloat(weekdays.count) * columnSpacing
            let dayWidth = max(
                (
                    availableWidth
                        - timeRailWidth
                        - gapsWidth
                ) / CGFloat(weekdays.count),
                44
            )
            let boardWidth = timeRailWidth
                + CGFloat(weekdays.count) * (dayWidth + columnSpacing)

            ScrollView(.vertical) {
                LazyVStack(spacing: rowSpacing) {
                    boardHeader(
                        weekdays: weekdays,
                        coursesByWeekday: coursesByWeekday,
                        dayWidth: dayWidth
                    )

                    ForEach(displayedBlocks) { block in
                        boardRow(
                            block: block,
                            weekdays: weekdays,
                            coursesBySlot: coursesBySlot,
                            dayWidth: dayWidth
                        )
                    }
                }
                .frame(width: boardWidth, alignment: .leading)
                .padding(.vertical, 8)
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
            }
            .scrollIndicators(.automatic)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func boardHeader(
        weekdays: [Int],
        coursesByWeekday: [Int: [Course]],
        dayWidth: CGFloat
    ) -> some View {
        HStack(spacing: columnSpacing) {
            VStack(alignment: .trailing, spacing: 1) {
                Text("节次")
                    .font(.caption.weight(.semibold))
                Text("时间")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(
                width: timeRailWidth,
                height: headerHeight,
                alignment: .trailing
            )

            ForEach(weekdays, id: \.self) { weekday in
                ScheduleDayHeader(
                    weekday: weekday,
                    courseCount: coursesByWeekday[weekday]?.count ?? 0,
                    isToday: weekday == model.todayWeekday,
                    usesCompactLayout: dayWidth < 96
                )
                .frame(width: dayWidth, height: headerHeight)
            }
        }
    }

    private func boardRow(
        block: TeachingBlock,
        weekdays: [Int],
        coursesBySlot: [CourseSlotKey: [Course]],
        dayWidth: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            TeachingTimeRail(block: block)
                .frame(width: timeRailWidth, height: rowHeight)

            ForEach(weekdays, id: \.self) { weekday in
                CourseSlotView(
                    courses: coursesBySlot[
                        CourseSlotKey(
                            weekday: weekday,
                            period: block.period
                        )
                    ] ?? [],
                    block: block,
                    week: model.week,
                    detailID: model.courseDetailID,
                    toggleDetails: model.toggleCourseDetails,
                    dismissDetails: model.dismissCourseDetails
                )
                .frame(width: dayWidth, height: rowHeight)
            }
        }
    }
}

private struct ScheduleDayHeader: View {
    let weekday: Int
    let courseCount: Int
    let isToday: Bool
    let usesCompactLayout: Bool

    @Environment(\.appAccent) private var accent

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    var body: some View {
        Group {
            if usesCompactLayout {
                VStack(spacing: 2) {
                    dayName
                    dayStatus
                }
            } else {
                HStack(spacing: 6) {
                    dayName
                    todayBadge
                    dayStatus
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            shape.fill(
                isToday
                    ? accent.opacity(0.085)
                    : Color.primary.opacity(0.025)
            )
        }
        .overlay {
            shape.strokeBorder(
                Color.primary.opacity(0.045),
                lineWidth: 1
            )
        }
    }

    private var dayName: some View {
        Text("周\(Course.shortWeekdayName(for: weekday))")
            .font(
                .system(
                    size: usesCompactLayout ? 11 : 13,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private var todayBadge: some View {
        if isToday {
            Text("今天")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(accent.opacity(0.11), in: Capsule())
        }
    }

    private var dayStatus: some View {
        Text(
            isToday && usesCompactLayout
                ? "今天"
                : courseCount == 0 ? "无课" : "\(courseCount)门"
        )
        .font(.system(size: 8.5, weight: .medium))
        .foregroundStyle(isToday ? accent : Color.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
}

private struct TeachingTimeRail: View {
    let block: TeachingBlock

    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(block.startTime ?? "待定")
                    .font(
                        .system(
                            size: 9.5,
                            weight: .medium,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 1.5) {
                    Text(block.sectionLabel)
                        .font(
                            .system(
                                size: 14.5,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("节")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(block.endTime ?? "")
                    .font(
                        .system(
                            size: 9.5,
                            weight: .medium,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Capsule()
                .fill(Color.primary.opacity(0.09))
                .frame(width: 1)
                .padding(.vertical, 9)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "第 \(block.sectionLabel) 节，\(block.timeRangeText)"
        )
    }
}

private struct CourseSlotView: View {
    let courses: [Course]
    let block: TeachingBlock
    let week: Int
    let detailID: String?
    let toggleDetails: (Course) -> Void
    let dismissDetails: () -> Void

    private var emptyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    var body: some View {
        if let course = courses.first {
            CourseCardView(
                course: course,
                block: block,
                week: week,
                additionalCourseCount: max(courses.count - 1, 0),
                isShowingDetails: detailID == course.id,
                toggleDetails: { toggleDetails(course) },
                dismissDetails: dismissDetails
            )
        } else {
            emptyShape
                .fill(Color.clear)
                .overlay {
                    emptyShape.strokeBorder(
                        Color.primary.opacity(0.035),
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: [3, 5]
                        )
                    )
                }
                .accessibilityHidden(true)
        }
    }
}
