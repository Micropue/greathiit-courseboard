import CourseBoardCore
import Foundation

enum ICSReminderPreset: String, CaseIterable, Identifiable {
    case none
    case atStart
    case fiveMinutes
    case tenMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case oneDay
    case twoDays
    case custom

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .none: "无"
        case .atStart: "日程发生时"
        case .fiveMinutes: "5 分钟前"
        case .tenMinutes: "10 分钟前"
        case .fifteenMinutes: "15 分钟前"
        case .thirtyMinutes: "30 分钟前"
        case .oneHour: "1 小时前"
        case .twoHours: "2 小时前"
        case .oneDay: "1 天前"
        case .twoDays: "2 天前"
        case .custom: "自定义…"
        }
    }

    var fixedMinutesBeforeStart: Int? {
        switch self {
        case .none, .custom: nil
        case .atStart: 0
        case .fiveMinutes: 5
        case .tenMinutes: 10
        case .fifteenMinutes: 15
        case .thirtyMinutes: 30
        case .oneHour: 60
        case .twoHours: 120
        case .oneDay: 24 * 60
        case .twoDays: 2 * 24 * 60
        }
    }

    func reminder(
        customValue: Int,
        customUnit: ICSReminderUnit
    ) -> ICSReminder? {
        switch self {
        case .none:
            return nil
        case .custom:
            guard let minutes = customUnit.minutes(for: customValue) else {
                return nil
            }
            return ICSReminder(minutesBeforeStart: minutes)
        default:
            guard let minutes = fixedMinutesBeforeStart else {
                return nil
            }
            return ICSReminder(minutesBeforeStart: minutes)
        }
    }
}

enum ICSReminderUnit: String, CaseIterable, Identifiable {
    case minutes
    case hours
    case days

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .minutes: "分钟"
        case .hours: "小时"
        case .days: "天"
        }
    }

    func minutes(for value: Int) -> Int? {
        guard value > 0 else {
            return nil
        }

        let multiplier: Int
        switch self {
        case .minutes: multiplier = 1
        case .hours: multiplier = 60
        case .days: multiplier = 24 * 60
        }

        let result = value.multipliedReportingOverflow(by: multiplier)
        return result.overflow ? nil : result.partialValue
    }
}
