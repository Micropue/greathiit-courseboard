import Foundation

public enum TimetableAPIError: LocalizedError {
    case invalidResponse
    case unauthorized(String)
    case http(status: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效。"
        case .unauthorized(let message):
            return message
        case .http(let status, let message):
            return "请求失败（HTTP \(status)）：\(message)"
        }
    }
}

public final class TimetableAPI {
    public static let endpoint = URL(
        string: "https://api.greathiit.com/api/timetable/getDataWeek"
    )!

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchCourses(week: Int, jwt: String) async throws -> [Course] {
        var components = URLComponents(
            url: Self.endpoint,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "week", value: String(week))
        ]

        guard let url = components?.url else {
            throw TimetableAPIError.invalidResponse
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.httpMethod = "GET"
        request.setValue(jwt, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TimetableAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw TimetableAPIError.unauthorized(
                "JWT 已失效或没有访问权限，请更新令牌。"
            )
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TimetableAPIError.http(
                status: httpResponse.statusCode,
                message: responseMessage(from: data) ?? "未知错误"
            )
        }

        do {
            return try TimetableParser.parse(data)
        } catch TimetableParserError.unauthorized(let message) {
            throw TimetableAPIError.unauthorized(message)
        }
    }

    private func responseMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return nil
        }

        for key in ["msg", "message", "error", "errorMessage"] {
            if let value = dictionary[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}
