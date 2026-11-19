import Foundation

public enum TimetableParserError: LocalizedError {
    case invalidJSON
    case invalidResponse(String)
    case unauthorized(String)
    case server(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "服务器返回了无法识别的数据。"
        case .invalidResponse(let message):
            return message
        case .unauthorized(let message):
            return message
        case .server(let message):
            return message
        }
    }
}

public enum TimetableParser {
    private struct ShortcutFields {
        let building: String
        let room: String
        let period: Int
        let weekday: Int
    }

    public static func parse(_ data: Data) throws -> [Course] {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TimetableParserError.invalidJSON
        }

        if let rows = root as? [[String: Any]] {
            return rows.compactMap(parseCourse)
        }

        guard let dictionary = root as? [String: Any] else {
            throw TimetableParserError.invalidResponse("服务器返回的数据格式不正确。")
        }

        let message = firstString(
            in: dictionary,
            keys: ["msg", "message", "error", "errorMessage"]
        )

        if let code = firstInt(in: dictionary, keys: ["code", "status"]),
           code != 0,
           code != 200 {
            let text = message ?? "请求失败（\(code)）。"
            if code == 401 || code == 403 || containsAuthenticationHint(text) {
                throw TimetableParserError.unauthorized(text)
            }
            throw TimetableParserError.server(text)
        }

        guard let rawRows = dictionary["data"] else {
            throw TimetableParserError.invalidResponse(
                message ?? "服务器响应中没有课程数据。"
            )
        }

        guard let rows = rawRows as? [[String: Any]] else {
            throw TimetableParserError.invalidResponse(
                message ?? "课程数据格式不正确。"
            )
        }

        return rows.compactMap(parseCourse)
    }

    public static func parseCourse(_ row: [String: Any]) -> Course? {
        guard let name = firstString(
            in: row,
            keys: ["courseName", "course_name", "name", "course"]
        ), !name.isEmpty else {
            return nil
        }

        let timeAdd = firstString(
            in: row,
            keys: ["timeAdd", "time_add", "time", "schedule"]
        ) ?? ""
        let shortcutFields = parseShortcutSchedule(timeAdd)

        let directWeekday = firstInt(
            in: row,
            keys: ["weekday", "dayOfWeek", "weekDay", "day"]
        )
        let directPeriod = firstInt(
            in: row,
            keys: ["period", "section", "startSection", "startPeriod"]
        )

        guard let weekday = directWeekday ?? shortcutFields?.weekday,
              (1...7).contains(weekday) else {
            return nil
        }

        guard let period = directPeriod ?? shortcutFields?.period,
              period > 0 else {
            return nil
        }

        let directBuilding = firstString(
            in: row,
            keys: ["buildingName", "building", "teachingBuilding"]
        )
        let directRoom = firstString(
            in: row,
            keys: ["classroomName", "classroom", "roomName", "room"]
        )

        let building = normalizedBuilding(
            directBuilding ?? shortcutFields?.building ?? ""
        )
        let room = normalizedRoom(
            directRoom ?? shortcutFields?.room ?? "",
            building: building
        )

        let periodEnd = firstInt(
            in: row,
            keys: ["periodEnd", "endSection", "endPeriod"]
        ) ?? period

        let weeksText = firstString(
            in: row,
            keys: ["weeksText", "weekName", "teachingWeek"]
        ) ?? inferWeeks(from: timeAdd)

        return Course(
            name: name,
            teacher: firstString(
                in: row,
                keys: ["teacherName", "teacher_name", "teacher"]
            ) ?? "",
            building: building,
            room: room,
            place: firstString(
                in: row,
                keys: ["place", "location", "classroomPlace"]
            ),
            weekday: weekday,
            period: period,
            periodEnd: periodEnd,
            weeksText: weeksText,
            rawTimeAdd: timeAdd
        )
    }

    private static func parseShortcutSchedule(_ rawTimeAdd: String) -> ShortcutFields? {
        let normalized = rawTimeAdd
            .replacingOccurrences(of: "－", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let segment = normalized
            .split(separator: "-", omittingEmptySubsequences: true)
            .last
            .map(String.init) else {
            return nil
        }

        let characters = Array(segment)
        guard characters.count >= 11 else {
            return nil
        }

        let buildingCode = String(characters[3])
        let room = String(characters[4...6])
        guard let period = Int(String(characters[9])),
              let weekday = Int(String(characters[10])),
              (1...7).contains(weekday),
              period > 0 else {
            return nil
        }

        return ShortcutFields(
            building: buildingCode,
            room: room,
            period: period,
            weekday: weekday
        )
    }

    private static func normalizedBuilding(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "1":
            return "A"
        case "2":
            return "B"
        default:
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func normalizedRoom(_ value: String, building: String) -> String {
        let room = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !room.isEmpty,
              !building.isEmpty,
              room.uppercased().hasPrefix(building.uppercased()) else {
            return room
        }
        return String(room.dropFirst(building.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "- "))
    }

    private static func inferWeeks(from rawTimeAdd: String) -> String? {
        let pattern = #"\d{1,2}(?:\s*[-–~至]\s*\d{1,2})?\s*周"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: rawTimeAdd,
                range: NSRange(rawTimeAdd.startIndex..., in: rawTimeAdd)
              ),
              let range = Range(match.range, in: rawTimeAdd) else {
            return nil
        }
        return String(rawTimeAdd[range])
    }

    private static func firstString(
        in dictionary: [String: Any],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
            if let number = dictionary[key] as? NSNumber {
                return number.stringValue
            }
        }
        return nil
    }

    private static func firstInt(
        in dictionary: [String: Any],
        keys: [String]
    ) -> Int? {
        for key in keys {
            if let number = dictionary[key] as? NSNumber {
                return number.intValue
            }
            if let string = dictionary[key] as? String,
               let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return value
            }
        }
        return nil
    }

    private static func containsAuthenticationHint(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("jwt")
            || lowercased.contains("token")
            || message.contains("登录")
            || message.contains("认证")
            || message.contains("授权")
    }
}
