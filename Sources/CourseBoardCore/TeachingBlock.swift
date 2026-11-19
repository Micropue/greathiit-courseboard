import Foundation

public struct TeachingBlock: Identifiable, Hashable, Sendable {
    public let period: Int
    public let sections: ClosedRange<Int>
    public let startTime: String?
    public let endTime: String?

    public static let standardFirstStartMinutes = 8 * 60 + 20

    public var id: Int {
        period
    }

    public var sectionLabel: String {
        "\(sections.lowerBound)–\(sections.upperBound)"
    }

    public var title: String {
        "第 \(sectionLabel) 节"
    }

    public var timeRangeText: String {
        guard let startTime, let endTime else {
            return "时间待定"
        }
        return "\(startTime)–\(endTime)"
    }

    public static let standard: [TeachingBlock] = [
        TeachingBlock(period: 1, sections: 1...2, startTime: "08:20", endTime: "09:50"),
        TeachingBlock(period: 2, sections: 3...4, startTime: "10:05", endTime: "11:35"),
        TeachingBlock(period: 3, sections: 5...6, startTime: "12:55", endTime: "14:25"),
        TeachingBlock(period: 4, sections: 7...8, startTime: "14:40", endTime: "16:10"),
        TeachingBlock(period: 5, sections: 9...10, startTime: "17:30", endTime: "19:00")
    ]

    public static func schedule(firstStartMinutes: Int) -> [TeachingBlock] {
        let latestStart = 23 * 60 + 59 - (
            minutes(from: standard.last?.endTime ?? "19:00")!
                - standardFirstStartMinutes
        )
        let normalizedStart = min(
            max(firstStartMinutes, 0),
            latestStart
        )
        let offset = normalizedStart - standardFirstStartMinutes

        return standard.map { block in
            TeachingBlock(
                period: block.period,
                sections: block.sections,
                startTime: block.startTime.flatMap {
                    minutes(from: $0).map {
                        timeString(minutes: $0 + offset)
                    }
                },
                endTime: block.endTime.flatMap {
                    minutes(from: $0).map {
                        timeString(minutes: $0 + offset)
                    }
                }
            )
        }
    }

    public static func minutes(from time: String) -> Int? {
        let parts = time.split(
            separator: ":",
            omittingEmptySubsequences: false
        )
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else {
            return nil
        }
        return hour * 60 + minute
    }

    public static func timeString(minutes: Int) -> String {
        let normalized = ((minutes % (24 * 60)) + 24 * 60) % (24 * 60)
        return String(
            format: "%02d:%02d",
            normalized / 60,
            normalized % 60
        )
    }

    public static func block(for period: Int) -> TeachingBlock {
        if let block = standard.first(where: { $0.period == period }) {
            return block
        }

        let firstSection = max(1, (period - 1) * 2 + 1)
        return TeachingBlock(
            period: period,
            sections: firstSection...(firstSection + 1),
            startTime: nil,
            endTime: nil
        )
    }

    public static func displayBlocks(
        for courses: [Course],
        using blocks: [TeachingBlock] = standard
    ) -> [TeachingBlock] {
        let highestPeriod = max(
            blocks.count,
            courses.map(\.period).max() ?? blocks.count
        )
        return (1...max(highestPeriod, 1)).map { period in
            blocks.first(where: { $0.period == period })
                ?? block(for: period)
        }
    }
}
