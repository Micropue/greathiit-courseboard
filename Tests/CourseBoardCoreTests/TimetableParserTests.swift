import CourseBoardCore
import XCTest

final class TimetableParserTests: XCTestCase {
    func testParsesShortcutScheduleEncoding() throws {
        let json = """
        {
          "code": 200,
          "data": [
            {
              "courseName": "数据结构",
              "teacherName": "张老师",
              "timeAdd": "1-16周-20211010232"
            }
          ]
        }
        """.data(using: .utf8)!

        let courses = try TimetableParser.parse(json)

        XCTAssertEqual(courses.count, 1)
        XCTAssertEqual(courses[0].name, "数据结构")
        XCTAssertEqual(courses[0].teacher, "张老师")
        XCTAssertEqual(courses[0].building, "A")
        XCTAssertEqual(courses[0].room, "101")
        XCTAssertEqual(courses[0].weekday, 2)
        XCTAssertEqual(courses[0].period, 3)
        XCTAssertEqual(courses[0].location, "A-101")
    }

    func testSecondBuildingCodeMapsToB() throws {
        let row: [String: Any] = [
            "courseName": "计算机网络",
            "timeAdd": "1-8周-20221040354"
        ]

        let course = try XCTUnwrap(TimetableParser.parseCourse(row))

        XCTAssertEqual(course.building, "B")
        XCTAssertEqual(course.room, "104")
        XCTAssertEqual(course.period, 5)
        XCTAssertEqual(course.weekday, 4)
    }

    func testDirectFieldsTakePrecedence() throws {
        let row: [String: Any] = [
            "courseName": "操作系统",
            "timeAdd": "1-16周-20211010232",
            "weekday": 5,
            "period": 7,
            "periodEnd": 8,
            "buildingName": "实验楼",
            "classroomName": "305",
            "weeksText": "1-16周"
        ]

        let course = try XCTUnwrap(TimetableParser.parseCourse(row))

        XCTAssertEqual(course.weekday, 5)
        XCTAssertEqual(course.period, 7)
        XCTAssertEqual(course.periodEnd, 8)
        XCTAssertEqual(course.location, "实验楼 305")
        XCTAssertEqual(course.weeksText, "1-16周")
    }

    func testSkipsRowsWithoutDayOrPeriod() {
        let row: [String: Any] = [
            "courseName": "无效课程",
            "timeAdd": "too-short"
        ]

        XCTAssertNil(TimetableParser.parseCourse(row))
    }

    func testAuthorizationResponse() {
        let json = """
        {"code": 401, "message": "JWT 已过期"}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try TimetableParser.parse(json)) { error in
            guard case TimetableParserError.unauthorized = error else {
                return XCTFail("Expected unauthorized error, got \(error)")
            }
        }
    }
}
