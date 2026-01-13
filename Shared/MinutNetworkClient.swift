// MinutNetworkClient.swift
// Shared networking client for Minut API operations

import Foundation
import os.log

private let logger = Logger(subsystem: SharedSettings.suiteName, category: "Network")

// MARK: - Network Client

class MinutNetworkClient {
    static let shared = MinutNetworkClient()

    private let baseURL = "https://api.minut.com/v8"
    private let tokenEndpoint = "https://api.minut.com/v8/oauth/token"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Token Management

    /// Exchange authorization code for tokens (initial OAuth sign-in)
    func exchangeCodeForTokens(code: String) async throws -> MinutCredentials {
        logger.info("🔄 Exchanging authorization code for tokens...")

        guard let url = URL(string: tokenEndpoint) else {
            throw MinutAuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": SharedSettings.clientId,
            "client_secret": SharedSettings.clientSecret,
            "redirect_uri": SharedSettings.redirectUri
        ]

        request.httpBody = bodyParams.urlEncodedData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinutAuthError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ Token exchange failed: \(errorMessage)")
            throw MinutAuthError.tokenExchangeFailed("Status \(httpResponse.statusCode): \(errorMessage)")
        }

        let tokenResponse = try JSONDecoder().decode(MinutTokenResponse.self, from: data)
        logger.info("✅ Token exchange successful")

        return MinutCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }

    func getValidAccessToken() async throws -> String {
        logger.info("🔑 Checking for credentials...")
        guard var credentials = KeychainHelper.loadCredentials() else {
            logger.error("❌ No credentials found in keychain")
            throw MinutAuthError.missingCredentials
        }

        logger.info("✅ Credentials loaded, expires at: \(credentials.expiresAt)")

        if credentials.isExpiringSoon {
            logger.warning("⚠️ Token expiring soon, refreshing...")
            credentials = try await refreshToken(credentials.refreshToken)
            try KeychainHelper.saveCredentials(credentials)
            logger.info("✅ Token refreshed successfully")
        } else {
            logger.info("✅ Token still valid")
        }

        return credentials.accessToken
    }

    private func refreshToken(_ refreshToken: String) async throws -> MinutCredentials {
        logger.info("🔄 Starting token refresh...")

        guard let url = URL(string: tokenEndpoint) else {
            throw MinutAuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": SharedSettings.clientId,
            "client_secret": SharedSettings.clientSecret
        ]

        request.httpBody = bodyParams.urlEncodedData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("❌ Token refresh failed with status \(statusCode)")
            throw MinutAuthError.refreshFailed("Token refresh failed with status \(statusCode)")
        }

        let tokenResponse = try JSONDecoder().decode(MinutTokenResponse.self, from: data)

        return MinutCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }

    // MARK: - Homes

    func getHomes(accessToken: String) async throws -> [MinutHome] {
        logger.info("📡 Getting homes list")
        let data = try await performRequest(
            endpoint: "/homes",
            method: "GET",
            accessToken: accessToken
        )

        let response = try JSONDecoder().decode(MinutHomesResponse.self, from: data)
        logger.info("✅ Retrieved \(response.homes.count) homes")
        return response.homes
    }

    // MARK: - Alarm Status

    func getAlarmStatus(homeId: String, accessToken: String) async throws -> AlarmInfo {
        logger.info("📡 Getting alarm status for home \(homeId, privacy: .private)")

        let data = try await performRequest(
            endpoint: "/homes/\(homeId)",
            method: "GET",
            accessToken: accessToken
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let homeResponse = try decoder.decode(MinutHomeResponse.self, from: data)

        let gracePeriod = homeResponse.alarm.gracePeriodExpiresAt?.ISO8601Format() ?? "none"
        logger.info("✅ Alarm status: \(homeResponse.alarm.alarmStatus.rawValue), grace period: \(gracePeriod)")

        return homeResponse.alarm
    }

    func setAlarmStatus(homeId: String, enabled: Bool, accessToken: String) async throws {
        logger.info("📡 Setting alarm to \(enabled ? "ON" : "OFF") for home \(homeId, privacy: .private)")

        let body = MinutAlarmUpdateRequest(
            alarmStatus: enabled ? .on : .off,
            alarmMode: .manual,
            silentAlarm: false,
            scheduledAlarmActive: false
        )

        _ = try await performRequest(
            endpoint: "/homes/\(homeId)/alarm",
            method: "PATCH",
            accessToken: accessToken,
            body: try JSONEncoder().encode(body)
        )

        logger.info("✅ Successfully set alarm status")
    }

    // MARK: - Request Helper

    private func performRequest(
        endpoint: String,
        method: String,
        accessToken: String,
        body: Data? = nil
    ) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw MinutAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("❌ Network error: \(error.localizedDescription)")
            throw MinutAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinutAPIError.unknown
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            logger.error("❌ Unauthorized (401)")
            throw MinutAPIError.unauthorized
        case 403:
            logger.error("❌ Forbidden (403)")
            throw MinutAPIError.forbidden
        case 404:
            logger.error("❌ Not found (404)")
            throw MinutAPIError.notFound
        default:
            logger.error("❌ Server error (\(httpResponse.statusCode))")
            throw MinutAPIError.serverError(httpResponse.statusCode)
        }
    }
}

// MARK: - URL Encoding Helper

extension Dictionary where Key == String, Value == String {
    var urlEncodedData: Data? {
        map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}
