import CourseBoardCore
import XCTest

final class TeachingBlockTests: XCTestCase {
    func testStandardTeachingTimes() {
        XCTAssertEqual(TeachingBlock.standard.count, 5)
        XCTAssertEqual(
            TeachingBlock.standard[0].timeRangeText,
            "08:20–09:50"
        )
        XCTAssertEqual(
            TeachingBlock.standard[4].sections,
            9...10
        )
        XCTAssertEqual(
            TeachingBlock.standard[4].timeRangeText,
            "17:30–19:00"
        )
    }

    func testDisplaysAllStandardBlocksWhenScheduleIsEmpty() {
        XCTAssertEqual(
            TeachingBlock.displayBlocks(for: []).map(\.period),
            [1, 2, 3, 4, 5]
        )
    }

    func testCustomFirstClassTimePreservesBreaks() {
        let blocks = TeachingBlock.schedule(
            firstStartMinutes: 8 * 60 + 35
        )

        XCTAssertEqual(blocks[0].timeRangeText, "08:35–10:05")
        XCTAssertEqual(blocks[1].timeRangeText, "10:20–11:50")
        XCTAssertEqual(blocks[4].timeRangeText, "17:45–19:15")
    }
}
