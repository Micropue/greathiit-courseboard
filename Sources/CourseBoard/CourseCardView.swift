import CourseBoardCore
import SwiftUI

struct CourseCardView: View {
    let course: Course
    let block: TeachingBlock
    let week: Int
    let additionalCourseCount: Int
    let isShowingDetails: Bool
    let toggleDetails: () -> Void
    let dismissDetails: () -> Void

    @Environment(\.appAccent) private var accent

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
    }

    var body: some View {
        Button(action: toggleDetails) {
            cardContent
        }
        .buttonStyle(.plain)
        .contentShape(cardShape)
        .help("查看 \(course.name) 的详细信息")
        .accessibilityLabel(accessibilityTitle)
        .accessibilityHint("点按打开课程详细信息")
        .popover(
            isPresented: Binding(
                get: { isShowingDetails },
                set: { isPresented in
                    if !isPresented, isShowingDetails {
                        dismissDetails()
                    }
                }
            ),
            arrowEdge: .trailing
        ) {
            CourseDetailPopover(
                course: course,
                block: block,
                week: week
            )
            .frame(width: 300)
        }
    }

    private var cardContent: some View {
        compactLayout
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            cardShape
                .fill(accent.opacity(0.085))
        }
        .overlay {
            cardShape.strokeBorder(
                Color.primary.opacity(0.075),
                lineWidth: 1
            )
        }
        .contentShape(cardShape)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(course.name)
                    .font(
                        .system(
                            size: 13.5,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 2)

                if additionalCourseCount > 0 {
                    Text("+\(additionalCourseCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(
                            accent.opacity(0.10),
                            in: Capsule()
                        )
                }
            }

            if !course.location.isEmpty {
                Text(course.location)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            if !course.teacher.isEmpty {
                Text(course.teacher)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 9)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    private var accessibilityTitle: String {
        [
            course.name,
            "第 \(block.sectionLabel) 节",
            course.location,
            course.teacher
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "，")
    }
}

private struct CourseDetailPopover: View {
    let course: Course
    let block: TeachingBlock
    let week: Int

    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .glassEffect(
                        .regular.tint(accent.opacity(0.10)),
                        in: RoundedRectangle(
                            cornerRadius: 11,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(.headline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(course.weekdayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Grid(
                alignment: .leading,
                horizontalSpacing: 16,
                verticalSpacing: 9
            ) {
                detailRow(
                    title: "节次",
                    value: "第 \(block.sectionLabel) 节"
                )
                detailRow(title: "时间", value: block.timeRangeText)
                detailRow(
                    title: "地点",
                    value: course.location.isEmpty
                        ? "未提供"
                        : course.location
                )
                detailRow(
                    title: "教师",
                    value: course.teacher.isEmpty
                        ? "未提供"
                        : course.teacher
                )
                detailRow(
                    title: "教学周",
                    value: course.weeksText ?? "第 \(week) 周"
                )
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private func detailRow(
        title: String,
        value: String
    ) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout.weight(.medium))
                .textSelection(.enabled)
        }
    }
}
