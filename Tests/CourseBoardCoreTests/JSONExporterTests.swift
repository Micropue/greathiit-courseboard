import CourseBoardCore
import XCTest

final class JSONExporterTests: XCTestCase {
    func testExportsExpectedFields() throws {
        let course = Course(
            name: "通信工程专业导论",
            teacher: "赵月",
            place: "综合楼313",
            weekday: 1,
            period: 1,
            periodEnd: 2,
            weeksText: "6-7"
        )

        let result = try JSONExporter.makeExport(from: [course])
        let rows = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(result.text.utf8)
            ) as? [[String: String]]
        )

        XCTAssertEqual(result.courseCount, 1)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["name"], "通信工程专业导论")
        XCTAssertEqual(rows[0]["teacher"], "赵月")
        XCTAssertEqual(rows[0]["classRoom"], "综合楼313")
        XCTAssertEqual(rows[0]["weekday"], "星期一")
        XCTAssertEqual(rows[0]["fixWeeks"], "6-7周")
        XCTAssertEqual(rows[0]["courseNumbers"], "1-2节")
        XCTAssertTrue(result.text.contains("\n  {\n"))
        XCTAssertTrue(result.text.hasSuffix("\n"))
    }

    func testFormatsSinglePeriod() throws {
        let course = Course(
            name: "大学英语",
            teacher: "李老师",
            building: "A",
            room: "426",
            weekday: 6,
            period: 5,
            weeksText: "1-20周"
        )

        let result = try JSONExporter.makeExport(from: [course])
        let rows = try decodeRows(result.text)

        XCTAssertEqual(rows[0]["classRoom"], "A-426")
        XCTAssertEqual(rows[0]["weekday"], "星期六")
        XCTAssertEqual(rows[0]["courseNumbers"], "5节")
        XCTAssertEqual(rows[0]["fixWeeks"], "1-20周")
    }

    func testDeduplicatesCoursesAcrossWeeksAndSorts() throws {
        let first = Course(
            name: "计算机网络",
            teacher: "孙亮",
            building: "A",
            room: "221",
            weekday: 4,
            period: 7,
            periodEnd: 8,
            weeksText: "1-20周"
        )
        let earlier = Course(
            name: "离散数学",
            teacher: "薛璐璐",
            place: "A221",
            weekday: 1,
            period: 3,
            periodEnd: 4,
            weeksText: "1-20周"
        )

        let result = try JSONExporter.makeExport(
            from: [first, earlier, first, first]
        )
        let rows = try decodeRows(result.text)

        XCTAssertEqual(result.courseCount, 2)
        XCTAssertEqual(rows.map { $0["name"] }, ["离散数学", "计算机网络"])
    }

    func testRejectsEmptyCourseList() {
        XCTAssertThrowsError(
            try JSONExporter.makeExport(from: [])
        ) {
            XCTAssertEqual($0 as? JSONExporterError, .noCourses)
        }
    }

    private func decodeRows(_ text: String) throws -> [[String: String]] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(text.utf8)
            ) as? [[String: String]]
        )
    }
}
