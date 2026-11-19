import CourseBoardCore
import XCTest

final class ICSWriterTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    func testExpandsCourseIntoLocalCalendarDateAsUTC() throws {
        let course = Course(
            name: "计算机网络",
            teacher: "孙亮",
            building: "A",
            room: "221",
            weekday: 2,
            period: 1
        )
        let calendar = try ICSWriter.makeCalendar(
            weeks: [
                ICSExportWeek(
                    week: 1,
                    startDate: date(year: 2026, month: 9, day: 7),
                    courses: [course]
                )
            ],
            generatedAt: date(
                year: 2026,
                month: 8,
                day: 1,
                hour: 12
            )
        )

        XCTAssertTrue(calendar.contains("DTSTART:20260908T002000Z"))
        XCTAssertTrue(calendar.contains("DTEND:20260908T015000Z"))
        XCTAssertTrue(calendar.contains("DTSTAMP:20260801T040000Z"))
        XCTAssertTrue(calendar.contains("LOCATION:A-221"))
        XCTAssertTrue(calendar.contains("X-WR-TIMEZONE:Asia/Shanghai"))
    }

    func testUsesIndividualWeekStartDates() throws {
        let course = Course(
            name: "算法分析",
            weekday: 3,
            period: 3
        )
        let calendar = try ICSWriter.makeCalendar(
            weeks: [
                ICSExportWeek(
                    week: 9,
                    startDate: date(year: 2026, month: 10, day: 7),
                    courses: [course]
                ),
                ICSExportWeek(
                    week: 10,
                    startDate: date(year: 2026, month: 10, day: 19),
                    courses: [course]
                )
            ]
        )

        XCTAssertTrue(calendar.contains("DTSTART:20261009T045500Z"))
        XCTAssertTrue(calendar.contains("DTSTART:20261021T045500Z"))
        XCTAssertEqual(
            calendar.components(separatedBy: "BEGIN:VEVENT").count - 1,
            2
        )
    }

    func testEscapesTextAndUsesStableDistinctUIDs() throws {
        let course = Course(
            name: "网络, 安全; 实验\\A\n班",
            teacher: "李老师",
            building: "B",
            room: "305",
            weekday: 4,
            period: 2
        )
        let week = ICSExportWeek(
            week: 3,
            startDate: date(year: 2026, month: 9, day: 21),
            courses: [course, course]
        )
        let first = try ICSWriter.makeCalendar(weeks: [week])
        let second = try ICSWriter.makeCalendar(weeks: [week])
        let unfolded = first.replacingOccurrences(of: "\r\n ", with: "")

        XCTAssertTrue(
            unfolded.contains("SUMMARY:网络\\, 安全\\; 实验\\\\A\\n班")
        )
        XCTAssertTrue(first.contains("UID:course-3-"))
        XCTAssertTrue(first.contains("-0@courseboard.local"))
        XCTAssertTrue(first.contains("-1@courseboard.local"))
        XCTAssertEqual(
            first.components(separatedBy: "BEGIN:VEVENT").count,
            second.components(separatedBy: "BEGIN:VEVENT").count
        )
        XCTAssertTrue(first.hasSuffix("\r\n"))
    }

    func testAllPhysicalLinesFitWithin75Octets() throws {
        let longName = String(
            repeating: "非常长的课程名称与教学说明",
            count: 12
        )
        let course = Course(
            name: longName,
            teacher: String(repeating: "教师姓名", count: 8),
            building: "A",
            room: "402",
            weekday: 5,
            period: 4
        )
        let calendar = try ICSWriter.makeCalendar(
            weeks: [
                ICSExportWeek(
                    week: 1,
                    startDate: date(year: 2026, month: 9, day: 7),
                    courses: [course]
                )
            ]
        )

        for line in calendar.components(separatedBy: "\r\n") {
            XCTAssertLessThanOrEqual(line.utf8.count, 75, line)
        }
    }

    func testEmptyWeekStillProducesValidCalendar() throws {
        let calendar = try ICSWriter.makeCalendar(
            weeks: [
                ICSExportWeek(
                    week: 1,
                    startDate: date(year: 2026, month: 9, day: 7),
                    courses: []
                )
            ]
        )

        XCTAssertTrue(calendar.hasPrefix("BEGIN:VCALENDAR\r\n"))
        XCTAssertFalse(calendar.contains("BEGIN:VEVENT"))
        XCTAssertTrue(calendar.hasSuffix("END:VCALENDAR\r\n"))
    }

    func testUsesCustomFirstClassTime() throws {
        let course = Course(name: "概率论", weekday: 1, period: 1)
        let calendar = try ICSWriter.makeCalendar(
            weeks: [
                ICSExportWeek(
                    week: 1,
                    startDate: date(year: 2026, month: 9, day: 7),
                    courses: [course]
                )
            ],
            blocks: TeachingBlock.schedule(
                firstStartMinutes: 8 * 60 + 35
            ),
            generatedAt: date(
                year: 2026,
                month: 8,
                day: 1,
                hour: 12
            )
        )

        XCTAssertTrue(calendar.contains("DTSTART:20260907T003500Z"))
        XCTAssertTrue(calendar.contains("DTEND:20260907T020500Z"))
    }

    func testRejectsUnknownPeriod() {
        let course = Course(name: "未知课程", weekday: 1, period: 9)
        let week = ICSExportWeek(
            week: 1,
            startDate: date(year: 2026, month: 9, day: 7),
            courses: [course]
        )

        XCTAssertThrowsError(try ICSWriter.makeCalendar(weeks: [week])) {
            XCTAssertEqual(
                $0 as? ICSWriterError,
                .unsupportedPeriod(week: 1, period: 9)
            )
        }
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(
                timeZone: timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
