import Foundation

public struct ICSExportWeek: Equatable, Sendable {
    public let week: Int
    public let startDate: Date
    public let courses: [Course]

    public init(week: Int, startDate: Date, courses: [Course]) {
        self.week = week
        self.startDate = startDate
        self.courses = courses
    }
}

public struct ICSReminder: Equatable, Sendable {
    public let minutesBeforeStart: Int

    public init(minutesBeforeStart: Int) {
        self.minutesBeforeStart = max(0, minutesBeforeStart)
    }

    var triggerValue: String {
        guard minutesBeforeStart > 0 else {
            return "PT0S"
        }

        let minutesPerHour = 60
        let minutesPerDay = 24 * minutesPerHour
        if minutesBeforeStart.isMultiple(of: minutesPerDay) {
            return "-P\(minutesBeforeStart / minutesPerDay)D"
        }
        if minutesBeforeStart.isMultiple(of: minutesPerHour) {
            return "-PT\(minutesBeforeStart / minutesPerHour)H"
        }
        return "-PT\(minutesBeforeStart)M"
    }
}

public enum ICSWriterError: LocalizedError, Equatable {
    case invalidWeek(Int)
    case invalidWeekday(week: Int, weekday: Int)
    case unsupportedPeriod(week: Int, period: Int)
    case invalidDate(week: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidWeek(let week):
            return "第 \(week) 周不是有效的教学周。"
        case .invalidWeekday(let week, let weekday):
            return "第 \(week) 周存在无效的星期设置（\(weekday)）。"
        case .unsupportedPeriod(let week, let period):
            return "第 \(week) 周存在无法确定上课时间的第 \(period) 节课程。"
        case .invalidDate(let week):
            return "无法计算第 \(week) 周的课程日期。"
        }
    }
}

public enum ICSWriter {
    public static let timeZoneIdentifier = "Asia/Shanghai"

    public static func makeCalendar(
        weeks: [ICSExportWeek],
        blocks: [TeachingBlock] = TeachingBlock.standard,
        reminder: ICSReminder? = nil,
        generatedAt: Date = Date()
    ) throws -> String {
        let calendar = teachingCalendar
        let events = try eventLines(
            weeks: weeks,
            blocks: blocks,
            reminder: reminder,
            generatedAt: generatedAt,
            calendar: calendar
        )
        let lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//CourseBoard//GreatHIT Courseboard//ZH-CN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:哈信息课程表",
            "X-WR-TIMEZONE:\(timeZoneIdentifier)",
            "X-WR-CALDESC:由哈信息课程表导出的教学周课程"
        ] + events + [
            "END:VCALENDAR"
        ]

        return lines
            .map(fold)
            .joined(separator: "\r\n") + "\r\n"
    }

    private static func eventLines(
        weeks: [ICSExportWeek],
        blocks: [TeachingBlock],
        reminder: ICSReminder?,
        generatedAt: Date,
        calendar: Calendar
    ) throws -> [String] {
        let dtstamp = utcFormatter.string(from: generatedAt)
        let blocksByPeriod = Dictionary(
            uniqueKeysWithValues: blocks.map { ($0.period, $0) }
        )
        var lines: [String] = []

        for exportWeek in weeks.sorted(by: { $0.week < $1.week }) {
            guard exportWeek.week > 0 else {
                throw ICSWriterError.invalidWeek(exportWeek.week)
            }

            let weekStart = calendar.startOfDay(for: exportWeek.startDate)
            var occurrences: [String: Int] = [:]

            for course in exportWeek.courses {
                guard (1...7).contains(course.weekday) else {
                    throw ICSWriterError.invalidWeekday(
                        week: exportWeek.week,
                        weekday: course.weekday
                    )
                }

                guard let block = blocksByPeriod[course.period],
                      let startTime = block.startTime,
                      let endTime = block.endTime else {
                    throw ICSWriterError.unsupportedPeriod(
                        week: exportWeek.week,
                        period: course.period
                    )
                }

                guard let dayOffset = calendar.date(
                    byAdding: .day,
                    value: course.weekday - 1,
                    to: weekStart
                ),
                let startDate = date(
                    on: dayOffset,
                    time: startTime,
                    calendar: calendar
                ),
                let endDate = date(
                    on: dayOffset,
                    time: endTime,
                    calendar: calendar
                ) else {
                    throw ICSWriterError.invalidDate(week: exportWeek.week)
                }

                let identity = [
                    course.name,
                    course.teacher,
                    course.building,
                    course.room,
                    course.place ?? "",
                    String(course.weekday),
                    String(course.period),
                    String(course.periodEnd),
                    course.rawTimeAdd
                ].joined(separator: "|")
                let baseUID = stableHash(identity)
                let occurrence = occurrences[baseUID, default: 0]
                occurrences[baseUID] = occurrence + 1
                let uid = "course-\(exportWeek.week)-\(baseUID)-\(occurrence)"
                    + "@courseboard.local"

                var descriptionParts = [
                    "教师：\(course.teacher.isEmpty ? "未填写" : course.teacher)",
                    "节次：\(block.title)",
                    "上课时间：\(block.timeRangeText)",
                    "教学周：第 \(exportWeek.week) 周"
                ]
                if let weeksText = course.weeksText, !weeksText.isEmpty {
                    descriptionParts.append("课程周次：\(weeksText)")
                }
                let description = descriptionParts.joined(separator: "\n")

                lines.append("BEGIN:VEVENT")
                lines.append("UID:\(uid)")
                lines.append("DTSTAMP:\(dtstamp)")
                lines.append("DTSTART:\(utcFormatter.string(from: startDate))")
                lines.append("DTEND:\(utcFormatter.string(from: endDate))")
                lines.append("SUMMARY:\(escape(course.name))")
                if !course.location.isEmpty {
                    lines.append("LOCATION:\(escape(course.location))")
                }
                lines.append("DESCRIPTION:\(escape(description))")
                lines.append("STATUS:CONFIRMED")
                lines.append("TRANSP:OPAQUE")
                if let reminder {
                    lines.append("BEGIN:VALARM")
                    lines.append("ACTION:DISPLAY")
                    lines.append(
                        "DESCRIPTION:\(escape("课程提醒：\(course.name)"))"
                    )
                    lines.append("TRIGGER:\(reminder.triggerValue)")
                    lines.append("END:VALARM")
                }
                lines.append("END:VEVENT")
            }
        }

        return lines
    }

    private static var teachingCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        calendar.firstWeekday = 2
        return calendar
    }

    private static let utcFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()

    private static func date(
        on day: Date,
        time: String,
        calendar: Calendar
    ) -> Date? {
        let parts = time.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }

        var components = calendar.dateComponents(
            [.year, .month, .day],
            from: day
        )
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)
    }

    private static func escape(_ value: String) -> String {
        var escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
        escaped = escaped
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
        return escaped
    }

    private static func fold(_ line: String) -> String {
        let byteLimit = 75
        var foldedLines: [String] = []
        var currentLine = ""
        var currentByteCount = 0

        for character in line {
            let characterByteCount = String(character).utf8.count
            if !currentLine.isEmpty,
               currentByteCount + characterByteCount > byteLimit {
                foldedLines.append(currentLine)
                currentLine = " "
                currentByteCount = 1
            }
            currentLine.append(character)
            currentByteCount += characterByteCount
        }

        foldedLines.append(currentLine)
        return foldedLines.joined(separator: "\r\n")
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}
