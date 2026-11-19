import Foundation

public struct Course: Identifiable, Codable, Hashable, Sendable {
    public let name: String
    public let teacher: String
    public let building: String
    public let room: String
    public let place: String?
    public let weekday: Int
    public let period: Int
    public let periodEnd: Int
    public let weeksText: String?
    public let rawTimeAdd: String

    public init(
        name: String,
        teacher: String = "",
        building: String = "",
        room: String = "",
        place: String? = nil,
        weekday: Int,
        period: Int,
        periodEnd: Int? = nil,
        weeksText: String? = nil,
        rawTimeAdd: String = ""
    ) {
        self.name = name
        self.teacher = teacher
        self.building = building
        self.room = room
        self.place = place
        self.weekday = weekday
        self.period = period
        self.periodEnd = max(period, periodEnd ?? period)
        self.weeksText = weeksText
        self.rawTimeAdd = rawTimeAdd
    }

    public var id: String {
        [
            String(weekday),
            String(period),
            String(periodEnd),
            name,
            teacher,
            building,
            room,
            place ?? "",
            rawTimeAdd
        ].joined(separator: "|")
    }

    public var weekdayName: String {
        Self.weekdayName(for: weekday)
    }

    public var shortWeekdayName: String {
        Self.shortWeekdayName(for: weekday)
    }

    public var periodLabel: String {
        if periodEnd > period {
            return "第 \(period)–\(periodEnd) 节"
        }
        return "第 \(period) 节"
    }

    public var location: String {
        let explicitPlace = place?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !explicitPlace.isEmpty {
            return explicitPlace
        }

        let cleanBuilding = building.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRoom = room.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanBuilding.isEmpty {
            return cleanRoom
        }
        if cleanRoom.isEmpty {
            return cleanBuilding
        }
        if cleanRoom.uppercased().hasPrefix(cleanBuilding.uppercased()) {
            return cleanRoom
        }
        if cleanBuilding.count == 1 {
            return "\(cleanBuilding)-\(cleanRoom)"
        }
        return "\(cleanBuilding) \(cleanRoom)"
    }

    public static func weekdayName(for weekday: Int) -> String {
        let names = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
        guard names.indices.contains(weekday - 1) else {
            return "未知"
        }
        return names[weekday - 1]
    }

    public static func shortWeekdayName(for weekday: Int) -> String {
        let names = ["一", "二", "三", "四", "五", "六", "日"]
        guard names.indices.contains(weekday - 1) else {
            return "?"
        }
        return names[weekday - 1]
    }
}
