import AppKit
import Combine
import CourseBoardCore
import Foundation
import SwiftUI

enum TeachingCalendar {
    static let weekCount = 20
    static let weeks = 1...weekCount
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
    private var didRequestInitialRefresh = false
    private var lastFetchAttempt: Date?

    var onHotKeyChange: ((GlobalHotKey.Spec) -> String?)?
    var onBeginHotKeyRecording: (() -> Void)?
    var onCancelHotKeyRecording: (() -> Void)?

    init() {
        let storedAccentTheme = UserDefaults.standard.string(
            forKey: "CourseBoard.accentTheme"
        )
        accentTheme = storedAccentTheme
            .flatMap(AppAccentTheme.init(rawValue:)) ?? .system

        let storedWeek = UserDefaults.standard.object(
            forKey: "CourseBoard.selectedWeek"
        ) as? Int
        week = min(max(storedWeek ?? 1, 1), TeachingCalendar.weekCount)

        hasJWT = KeychainStore.readToken()?.isEmpty == false
        refreshLaunchAtLoginState()
        loadCache()
    }

    deinit {
        fetchTask?.cancel()
    }

    var todayWeekday: Int {
        let calendarWeekday = Calendar.current.component(.weekday, from: Date())
        return ((calendarWeekday + 5) % 7) + 1
    }

    var accentColor: Color {
        accentTheme.color
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
}
