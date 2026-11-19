import AppKit
import Combine
import CourseBoardCore
import Foundation
import SwiftUI

enum TeachingCalendar {
    static let weekCount = 20
    static let weeks = 1...weekCount
}

private enum ICSExportFlowError: LocalizedError {
    case missingDates
    case noCourses

    var errorDescription: String? {
        switch self {
        case .missingDates:
            return "教学周日期尚未准备好，请重新设置第 1 周起始日。"
        case .noCourses:
            return "这 20 个教学周里没有读到任何课程，已停止导出。"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    private struct CachedSchedule: Codable {
        let week: Int
        let courses: [Course]
        let savedAt: Date
    }

    @Published var week: Int = 1
    @Published private(set) var courses: [Course] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasJWT: Bool
    @Published private(set) var errorMessage: String?
    @Published private(set) var errorRequiresJWT = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var hotKeySpec = GlobalHotKey.Spec.preferred
    @Published private(set) var hasRegisteredHotKey = false
    @Published private(set) var hotKeyError: String?
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginNeedsApproval = false
    @Published private(set) var launchAtLoginError: String?
    @Published var jwtDraft = ""
    @Published var isShowingSettings = false
    @Published var isRecordingHotKey = false
    @Published var courseDetailID: String?
    @Published private(set) var teachingWeekDates: [Date] = []
    @Published var isShowingICSExport = false
    @Published var isShowingICSFileExporter = false
    @Published private(set) var icsDocument: ICSDocument?
    @Published private(set) var icsExportFilename = "哈信息课程表.ics"
    @Published private(set) var icsExportEventCount = 0
    @Published private(set) var isExportingICS = false
    @Published private(set) var icsExportProgress = 0.0
    @Published private(set) var icsExportProgressText: String?
    @Published private(set) var icsExportError: String?
    @Published private(set) var icsExportNotice: String?
    @Published var isShowingICSNotice = false
    @Published private(set) var firstCourseStartMinutes: Int
    @Published var accentTheme: AppAccentTheme {
        didSet {
            defaults.set(
                accentTheme.rawValue,
                forKey: "CourseBoard.accentTheme"
            )
        }
    }

    private let api = TimetableAPI()
    private let defaults = UserDefaults.standard
    private var fetchTask: Task<Void, Never>?
    private var icsExportTask: Task<Void, Never>?
    private var didRequestInitialRefresh = false
    private var lastFetchAttempt: Date?

    var onHotKeyChange: ((GlobalHotKey.Spec) -> String?)?
    var onBeginHotKeyRecording: (() -> Void)?
    var onCancelHotKeyRecording: (() -> Void)?

    init() {
        let storedFirstCourseStart = UserDefaults.standard.object(
            forKey: "CourseBoard.firstCourseStartMinutes"
        ) as? Int
        firstCourseStartMinutes = TeachingBlock.schedule(
            firstStartMinutes: storedFirstCourseStart
                ?? TeachingBlock.standardFirstStartMinutes
        ).first?.startTime.flatMap(TeachingBlock.minutes(from:))
            ?? TeachingBlock.standardFirstStartMinutes

        let storedAccentTheme = UserDefaults.standard.string(
            forKey: "CourseBoard.accentTheme"
        )
        accentTheme = storedAccentTheme
            .flatMap(AppAccentTheme.init(rawValue:)) ?? .system

        let storedWeek = UserDefaults.standard.object(
            forKey: "CourseBoard.selectedWeek"
        ) as? Int
        let initialWeek = min(
            max(storedWeek ?? 1, 1),
            TeachingCalendar.weekCount
        )
        week = initialWeek

        let savedWeekDates = UserDefaults.standard.array(
            forKey: "CourseBoard.teachingWeekDates"
        ) as? [Double]
        if let savedWeekDates,
           savedWeekDates.count == TeachingCalendar.weekCount {
            teachingWeekDates = savedWeekDates.map {
                Self.teachingCalendar.startOfDay(
                    for: Date(timeIntervalSince1970: $0)
                )
            }
        } else {
            teachingWeekDates = Self.continuousWeekDates(
                startingAt: Self.estimatedFirstWeekStart(
                    currentWeek: initialWeek
                )
            )
        }

        hasJWT = KeychainStore.readToken()?.isEmpty == false
        refreshLaunchAtLoginState()
        loadCache()
    }

    deinit {
        fetchTask?.cancel()
        icsExportTask?.cancel()
    }

    var todayWeekday: Int {
        let calendarWeekday = Calendar.current.component(.weekday, from: Date())
        return ((calendarWeekday + 5) % 7) + 1
    }

    var accentColor: Color {
        accentTheme.color
    }

    var teachingBlocks: [TeachingBlock] {
        TeachingBlock.schedule(
            firstStartMinutes: firstCourseStartMinutes
        )
    }

    var firstCourseStartDate: Date {
        Self.teachingCalendar.date(
            bySettingHour: firstCourseStartMinutes / 60,
            minute: firstCourseStartMinutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    var firstCourseStartText: String {
        TeachingBlock.timeString(
            minutes: firstCourseStartMinutes
        )
    }

    func courses(on weekday: Int) -> [Course] {
        courses
            .filter { $0.weekday == weekday }
            .sorted {
                if $0.period == $1.period {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.period < $1.period
            }
    }

    func count(on weekday: Int) -> Int {
        courses(on: weekday).count
    }

    func refreshIfNeeded() {
        guard !didRequestInitialRefresh else {
            return
        }
        didRequestInitialRefresh = true
        if hasJWT {
            refresh()
        }
    }

    func refreshIfStale() {
        guard hasJWT else {
            return
        }
        let reference = lastUpdated ?? lastFetchAttempt ?? .distantPast
        if Date().timeIntervalSince(reference) > 300 {
            refresh()
        }
    }

    func previousWeek() {
        setWeek(week - 1)
    }

    func nextWeek() {
        setWeek(week + 1)
    }

    func setWeek(_ value: Int) {
        let nextValue = min(max(value, 1), TeachingCalendar.weekCount)
        guard nextValue != week else {
            return
        }
        week = nextValue
        defaults.set(nextValue, forKey: "CourseBoard.selectedWeek")
        courses = []
        lastUpdated = nil
        refresh()
    }

    func toggleCourseDetails(for course: Course) {
        courseDetailID = courseDetailID == course.id ? nil : course.id
    }

    func dismissCourseDetails() {
        courseDetailID = nil
    }

    func refresh() {
        guard hasJWT else {
            return
        }
        guard let token = KeychainStore.readToken(),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            hasJWT = false
            return
        }

        fetchTask?.cancel()
        isLoading = true
        errorMessage = nil
        errorRequiresJWT = false
        lastFetchAttempt = Date()

        let requestedWeek = week
        fetchTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let fetchedCourses = try await api.fetchCourses(
                    week: requestedWeek,
                    jwt: token
                )
                guard !Task.isCancelled, week == requestedWeek else {
                    return
                }
                courses = fetchedCourses
                lastUpdated = Date()
                errorMessage = nil
                errorRequiresJWT = false
                saveCache()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                if case TimetableAPIError.unauthorized(let message) = error {
                    errorRequiresJWT = true
                    errorMessage = message
                } else {
                    errorMessage = friendlyMessage(for: error)
                }
            }

            isLoading = false
        }
    }

    func saveJWT() {
        let token = jwtDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            errorMessage = "请先输入 JWT。"
            errorRequiresJWT = false
            return
        }

        guard KeychainStore.saveToken(token) else {
            errorMessage = "无法把 JWT 写入 macOS 钥匙串。"
            errorRequiresJWT = false
            return
        }

        hasJWT = true
        jwtDraft = ""
        errorMessage = nil
        errorRequiresJWT = false
        isShowingSettings = false
        refresh()
    }

    func pasteJWTFromClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string) else {
            return
        }
        jwtDraft = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func clearJWT() {
        _ = KeychainStore.deleteToken()
        fetchTask?.cancel()
        hasJWT = false
        jwtDraft = ""
        courses = []
        errorMessage = nil
        errorRequiresJWT = false
        lastUpdated = nil
        removeCache()
    }

    func clearError() {
        errorMessage = nil
        errorRequiresJWT = false
    }

    func presentICSExport() {
        guard hasJWT else {
            isShowingSettings = true
            return
        }
        if teachingWeekDates.count != TeachingCalendar.weekCount {
            resetTeachingWeekDatesFromCurrentWeek()
        }

        icsExportError = nil
        icsExportProgress = 0
        icsExportProgressText = nil
        icsExportEventCount = 0
        isShowingICSExport = true
    }

    func teachingWeekStartDate(for week: Int) -> Date {
        let index = min(
            max(week - 1, 0),
            teachingWeekDates.count - 1
        )
        guard teachingWeekDates.indices.contains(index) else {
            return Self.estimatedFirstWeekStart(currentWeek: self.week)
        }
        return teachingWeekDates[index]
    }

    func teachingWeekEndDate(for week: Int) -> Date {
        Self.teachingCalendar.date(
            byAdding: .day,
            value: 6,
            to: teachingWeekStartDate(for: week)
        ) ?? teachingWeekStartDate(for: week)
    }

    func shiftTeachingWeekStart(week: Int, to date: Date) {
        let index = week - 1
        guard teachingWeekDates.indices.contains(index) else {
            return
        }

        let normalizedDate = Self.teachingCalendar.startOfDay(for: date)
        let dayDelta = Self.teachingCalendar.dateComponents(
            [.day],
            from: teachingWeekDates[index],
            to: normalizedDate
        ).day ?? 0
        guard dayDelta != 0 else {
            return
        }

        for shiftedIndex in index..<teachingWeekDates.count {
            guard let shiftedDate = Self.teachingCalendar.date(
                byAdding: .day,
                value: dayDelta,
                to: teachingWeekDates[shiftedIndex]
            ) else {
                continue
            }
            teachingWeekDates[shiftedIndex] = shiftedDate
        }
        persistTeachingWeekDates()
    }

    func resetTeachingWeekDatesFromCurrentWeek() {
        teachingWeekDates = Self.continuousWeekDates(
            startingAt: Self.estimatedFirstWeekStart(currentWeek: week)
        )
        persistTeachingWeekDates()
    }

    func setFirstCourseStartTime(_ date: Date) {
        let components = Self.teachingCalendar.dateComponents(
            [.hour, .minute],
            from: date
        )
        guard let hour = components.hour,
              let minute = components.minute else {
            return
        }
        let normalizedStart = TeachingBlock.schedule(
            firstStartMinutes: hour * 60 + minute
        ).first?.startTime.flatMap(TeachingBlock.minutes(from:))
            ?? TeachingBlock.standardFirstStartMinutes
        firstCourseStartMinutes = normalizedStart
        defaults.set(
            normalizedStart,
            forKey: "CourseBoard.firstCourseStartMinutes"
        )
    }

    func dismissICSExport() {
        icsExportTask?.cancel()
        icsExportTask = nil
        isExportingICS = false
        icsExportProgressText = nil
        isShowingICSExport = false
    }

    func icsExportSheetDismissed() {
        guard isExportingICS else {
            return
        }
        dismissICSExport()
    }

    func exportICS() {
        guard !isExportingICS else {
            return
        }
        guard teachingWeekDates.count == TeachingCalendar.weekCount else {
            icsExportError = ICSExportFlowError.missingDates.localizedDescription
            return
        }
        guard let token = KeychainStore.readToken(),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            hasJWT = false
            icsExportError = "JWT 已失效，请先更新访问令牌。"
            return
        }

        isExportingICS = true
        icsExportError = nil
        icsExportEventCount = 0
        icsExportProgress = 0
        icsExportProgressText = "正在准备读取教学周…"

        let weekDates = teachingWeekDates
        icsExportTask?.cancel()
        icsExportTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                var exportWeeks: [ICSExportWeek] = []
                for week in TeachingCalendar.weeks {
                    try Task.checkCancellation()
                    icsExportProgressText = "正在读取第 \(week)/\(TeachingCalendar.weekCount) 周…"

                    let courses = try await api.fetchCourses(
                        week: week,
                        jwt: token
                    )
                    try Task.checkCancellation()

                    if !courses.isEmpty {
                        exportWeeks.append(
                            ICSExportWeek(
                                week: week,
                                startDate: weekDates[week - 1],
                                courses: courses
                            )
                        )
                    }
                    icsExportProgress =
                        Double(week) / Double(TeachingCalendar.weekCount)
                }

                let eventCount = exportWeeks.reduce(0) {
                    $0 + $1.courses.count
                }
                guard eventCount > 0 else {
                    throw ICSExportFlowError.noCourses
                }

                icsExportProgressText = "正在生成日历文件…"
                let calendarText = try ICSWriter.makeCalendar(
                    weeks: exportWeeks,
                    blocks: teachingBlocks
                )

                icsDocument = ICSDocument(text: calendarText)
                icsExportEventCount = eventCount
                icsExportFilename = Self.exportFilename(
                    firstWeekDate: weekDates[0]
                )
                isExportingICS = false
                icsExportProgressText = nil
                isShowingICSExport = false

                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else {
                    return
                }
                isShowingICSFileExporter = true
            } catch is CancellationError {
                isExportingICS = false
                icsExportProgressText = nil
            } catch {
                if isCancellation(error) {
                    isExportingICS = false
                    icsExportProgressText = nil
                    return
                }
                isExportingICS = false
                icsExportProgressText = nil
                icsExportError = friendlyMessage(for: error)
            }
        }
    }

    func handleICSFileExport(_ result: Result<URL, Error>) {
        isShowingICSFileExporter = false
        icsDocument = nil

        switch result {
        case .success(let url):
            showICSNotice(
                "已导出 \(icsExportEventCount) 个课程事件到 \(url.lastPathComponent)。"
            )
        case .failure(let error):
            if let cocoaError = error as? CocoaError,
               cocoaError.code == .userCancelled {
                return
            }
            showICSNotice("保存日历失败：\(error.localizedDescription)")
        }
    }

    func setRegisteredHotKey(
        _ spec: GlobalHotKey.Spec,
        notice: String? = nil
    ) {
        hotKeySpec = spec
        hasRegisteredHotKey = true
        hotKeyError = notice
        isRecordingHotKey = false
    }

    func reportHotKeyFailure(_ message: String) {
        hasRegisteredHotKey = false
        hotKeyError = message
        isRecordingHotKey = false
    }

    func beginHotKeyRecording() {
        hotKeyError = nil
        isRecordingHotKey = true
        onBeginHotKeyRecording?()
    }

    func cancelHotKeyRecording() {
        guard isRecordingHotKey else {
            return
        }
        isRecordingHotKey = false
        onCancelHotKeyRecording?()
    }

    func assignHotKey(_ spec: GlobalHotKey.Spec) {
        guard let onHotKeyChange else {
            reportHotKeyFailure("快捷键服务尚未准备好，请重新打开应用。")
            return
        }

        if let error = onHotKeyChange(spec) {
            hotKeyError = error
            isRecordingHotKey = false
            return
        }

        hotKeySpec = spec
        hasRegisteredHotKey = true
        hotKeyError = nil
        isRecordingHotKey = false
    }

    func reportInvalidHotKey() {
        hotKeyError = "快捷键至少需要包含 Control、Option 或 Command，Esc 可取消。"
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginError = nil

        do {
            try LaunchAtLoginManager.setEnabled(enabled)
        } catch {
            launchAtLoginError = "无法更新开机自启设置：\(error.localizedDescription)"
        }

        refreshLaunchAtLoginState()
        if enabled, launchAtLoginNeedsApproval {
            launchAtLoginError = "请前往“系统设置 → 通用 → 登录项”允许哈信息课程表。"
        }
    }

    func openLoginItemsSettings() {
        LaunchAtLoginManager.openSystemSettings()
    }

    var launchAtLoginStatusText: String {
        LaunchAtLoginManager.statusText
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginEnabled = LaunchAtLoginManager.isOn
        launchAtLoginNeedsApproval = LaunchAtLoginManager.needsApproval
    }

    private func friendlyMessage(for error: Error) -> String {
        if let error = error as? TimetableParserError,
           let description = error.errorDescription {
            return description
        }
        if let error = error as? TimetableAPIError,
           let description = error.errorDescription {
            return description
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "当前网络不可用。"
            case NSURLErrorTimedOut:
                return "连接学校服务器超时，请稍后重试。"
            case NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost:
                return "无法连接学校课程表服务器。"
            default:
                break
            }
        }
        return error.localizedDescription
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
            && nsError.code == NSURLErrorCancelled
    }

    private var cacheURL: URL? {
        guard let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        let directory = baseURL.appendingPathComponent(
            "CourseBoard",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("schedule.json")
    }

    private func loadCache() {
        guard let cacheURL,
              let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode(
                CachedSchedule.self,
                from: data
              ),
              cached.week == week else {
            return
        }
        courses = cached.courses
        lastUpdated = cached.savedAt
    }

    private func saveCache() {
        guard let cacheURL,
              let data = try? JSONEncoder().encode(
                CachedSchedule(
                    week: week,
                    courses: courses,
                    savedAt: lastUpdated ?? Date()
                )
              ) else {
            return
        }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func removeCache() {
        guard let cacheURL else {
            return
        }
        try? FileManager.default.removeItem(at: cacheURL)
    }

    private static var teachingCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(identifier: ICSWriter.timeZoneIdentifier)!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func estimatedFirstWeekStart(
        currentWeek: Int,
        referenceDate: Date = Date()
    ) -> Date {
        let day = teachingCalendar.startOfDay(for: referenceDate)
        let weekday = ((teachingCalendar.component(.weekday, from: day) + 5) % 7) + 1
        let monday = teachingCalendar.date(
            byAdding: .day,
            value: 1 - weekday,
            to: day
        ) ?? day
        return teachingCalendar.date(
            byAdding: .day,
            value: -(max(currentWeek, 1) - 1) * 7,
            to: monday
        ) ?? monday
    }

    private static func continuousWeekDates(startingAt firstWeekStart: Date) -> [Date] {
        let start = teachingCalendar.startOfDay(for: firstWeekStart)
        return (0..<TeachingCalendar.weekCount).compactMap {
            teachingCalendar.date(
                byAdding: .day,
                value: $0 * 7,
                to: start
            )
        }
    }

    private static func exportFilename(firstWeekDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = teachingCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = teachingCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "哈信息课程表-\(formatter.string(from: firstWeekDate)).ics"
    }

    private func persistTeachingWeekDates() {
        defaults.set(
            teachingWeekDates.map(\.timeIntervalSince1970),
            forKey: "CourseBoard.teachingWeekDates"
        )
    }

    private func showICSNotice(_ message: String) {
        icsExportNotice = message
        isShowingICSNotice = true
    }
}
