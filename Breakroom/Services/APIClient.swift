import Foundation

/// Notification posted when the user's session expires (401 response)
/// Observers should log the user out and return to the login screen
extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case subscriptionRequired
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            // This shouldn't be shown to users - the app auto-redirects to login
            return "Session expired"
        case .subscriptionRequired:
            return "Subscription required"
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    let baseURL: String = {
        // For testing: check UserDefaults (set via launch arguments: -TEST_API_URL http://localhost:3001)
        if let testURL = UserDefaults.standard.string(forKey: "TEST_API_URL"), !testURL.isEmpty {
            print("[APIClient] Using TEST_API_URL from launch args: \(testURL)")
            return testURL
        }
        // Use the configured environment (set via ./switch-env.sh)
        print("[APIClient] Using \(Config.environment) environment: \(Config.baseURL)")
        return Config.baseURL
    }()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    /// Check response for refreshed token and save it
    private func handleTokenRefresh(_ response: HTTPURLResponse) {
        if let newToken = response.value(forHTTPHeaderField: "X-New-Token") {
            KeychainManager.token = newToken
        }
    }

    private func buildRequest(
        path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let bearerToken = KeychainManager.bearerToken {
            request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        let request = try buildRequest(
            path: path,
            method: method,
            body: body,
            authenticated: authenticated
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        handleTokenRefresh(httpResponse)

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                #if DEBUG
                print("DECODE ERROR for \(T.self): \(error)")
                if let json = String(data: data, encoding: .utf8) {
                    print("RAW JSON (first 2000 chars): \(String(json.prefix(2000)))")
                }
                #endif
                throw APIError.decodingError(error)
            }
        case 401:
            await handleUnauthorized()
            throw APIError.unauthorized
        case 402:
            throw APIError.subscriptionRequired
        default:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.displayMessage)
            }
            throw APIError.serverError("Request failed with status \(httpResponse.statusCode)")
        }
    }

    func uploadMultipart<T: Decodable>(
        _ path: String,
        fileData: Data,
        fieldName: String,
        filename: String,
        mimeType: String,
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if authenticated, let bearerToken = KeychainManager.bearerToken {
            request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        handleTokenRefresh(httpResponse)

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            await handleUnauthorized()
            throw APIError.unauthorized
        case 402:
            throw APIError.subscriptionRequired
        default:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.displayMessage)
            }
            throw APIError.serverError("Request failed with status \(httpResponse.statusCode)")
        }
    }

    func requestVoid(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws {
        let request = try buildRequest(
            path: path,
            method: method,
            body: body,
            authenticated: authenticated
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        handleTokenRefresh(httpResponse)

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            await handleUnauthorized()
            throw APIError.unauthorized
        case 402:
            throw APIError.subscriptionRequired
        default:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.displayMessage)
            }
            throw APIError.serverError("Request failed with status \(httpResponse.statusCode)")
        }
    }

    /// Upload multipart form data with additional text fields
    func uploadMultipartWithFields<T: Decodable>(
        _ path: String,
        fileData: Data,
        fieldName: String,
        filename: String,
        mimeType: String,
        additionalFields: [String: String],
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if authenticated, let bearerToken = KeychainManager.bearerToken {
            request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // Add additional text fields
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        handleTokenRefresh(httpResponse)

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            await handleUnauthorized()
            throw APIError.unauthorized
        case 402:
            throw APIError.subscriptionRequired
        default:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.displayMessage)
            }
            throw APIError.serverError("Request failed with status \(httpResponse.statusCode)")
        }
    }

    /// Get redirect location URL from a 302 response (used for S3 streaming URLs)
    func getRedirectLocation(_ path: String, authenticated: Bool = true) async throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if authenticated, let bearerToken = KeychainManager.bearerToken {
            request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
        }

        // Use a session that doesn't follow redirects
        let noRedirectDelegate = NoRedirectDelegate()
        let noRedirectSession = URLSession(configuration: .default, delegate: noRedirectDelegate, delegateQueue: nil)

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await noRedirectSession.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 302:
            guard let location = httpResponse.value(forHTTPHeaderField: "Location"),
                  let redirectURL = URL(string: location) else {
                throw APIError.serverError("No redirect location in response")
            }
            return redirectURL
        case 401:
            await handleUnauthorized()
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Expected redirect, got status \(httpResponse.statusCode)")
        }
    }

    /// Handle 401 unauthorized response by posting notification to trigger logout
    private func handleUnauthorized() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
        }
    }
}

// MARK: - No Redirect Delegate

/// URLSession delegate that prevents automatic redirect following
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Return nil to prevent following the redirect
        completionHandler(nil)
    }
}
