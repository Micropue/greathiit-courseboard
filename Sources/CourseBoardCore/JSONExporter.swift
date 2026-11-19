import Foundation

public struct JSONExportCourse: Codable, Hashable, Sendable {
    public let name: String
    public let teacher: String
    public let classRoom: String
    public let weekday: String
    public let fixWeeks: String
    public let courseNumbers: String

    init(course: Course) {
        name = course.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        teacher = course.teacher.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        classRoom = course.location.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        weekday = course.weekdayName
        fixWeeks = Self.normalizedWeeks(course.weeksText)

        if course.periodEnd > course.period {
            courseNumbers = "\(course.period)-\(course.periodEnd)节"
        } else {
            courseNumbers = "\(course.period)节"
        }
    }

    private static func normalizedWeeks(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !value.isEmpty else {
            return ""
        }
        return value.hasSuffix("周") ? value : "\(value)周"
    }
}

public struct JSONExportResult: Equatable, Sendable {
    public let text: String
    public let courseCount: Int

    public init(text: String, courseCount: Int) {
        self.text = text
        self.courseCount = courseCount
    }
}

public enum JSONExporterError: LocalizedError, Equatable {
    case noCourses
    case invalidEncoding

    public var errorDescription: String? {
        switch self {
        case .noCourses:
            return "没有可导出的课程。"
        case .invalidEncoding:
            return "无法生成 UTF-8 编码的 JSON 文件。"
        }
    }
}

public enum JSONExporter {
    public static func makeExport(
        from courses: [Course]
    ) throws -> JSONExportResult {
        let sortedCourses = courses.sorted {
            if $0.weekday != $1.weekday {
                return $0.weekday < $1.weekday
            }
            if $0.period != $1.period {
                return $0.period < $1.period
            }
            if $0.periodEnd != $1.periodEnd {
                return $0.periodEnd < $1.periodEnd
            }
            return $0.name.localizedStandardCompare($1.name)
                == .orderedAscending
        }

        var seen = Set<JSONExportCourse>()
        var exportedCourses: [JSONExportCourse] = []
        for course in sortedCourses {
            let exportedCourse = JSONExportCourse(course: course)
            if seen.insert(exportedCourse).inserted {
                exportedCourses.append(exportedCourse)
            }
        }

        guard !exportedCourses.isEmpty else {
            throw JSONExporterError.noCourses
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(exportedCourses)
        guard var text = String(data: data, encoding: .utf8) else {
            throw JSONExporterError.invalidEncoding
        }
        if !text.hasSuffix("\n") {
            text.append("\n")
        }

        return JSONExportResult(
            text: text,
            courseCount: exportedCourses.count
        )
    }
}
