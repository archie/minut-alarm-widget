// WidgetAPIService.swift
// Lightweight API service for the widget extension

import Foundation
import os.log

private let logger = Logger(subsystem: "se.akacian.minut-alarm-widget", category: "WidgetAPI")

class WidgetAPIService {
    static let shared = WidgetAPIService()
    
    private let baseURL = "https://api.minut.com/v8"
    
    // OAuth config - must match main app
    private let clientId = SharedSettings.clientId
    private let clientSecret = SharedSettings.clientSecret
    private let tokenEndpoint = "https://api.minut.com/v8/oauth/token"
    
    private init() {}
    
    // MARK: - Token Management
    
    func getValidAccessToken() async throws -> String {
        logger.info("🔑 WidgetAPI: Checking for credentials...")
        guard var credentials = KeychainHelper.loadCredentials() else {
            logger.error("❌ WidgetAPI: No credentials found in keychain")
            throw MinutAuthError.missingCredentials
        }

        logger.info("✅ WidgetAPI: Credentials loaded, expires at: \(credentials.expiresAt)")

        // Refresh if expiring within 5 minutes
        if credentials.isExpiringSoon {
            logger.warning("⚠️ WidgetAPI: Token expiring soon, refreshing...")
            credentials = try await refreshToken(credentials.refreshToken)
            try KeychainHelper.saveCredentials(credentials)
            logger.info("✅ WidgetAPI: Token refreshed successfully")
        } else {
            logger.info("✅ WidgetAPI: Token still valid")
        }

        return credentials.accessToken
    }
    
    private func refreshToken(_ refreshToken: String) async throws -> MinutCredentials {
        logger.info("🔄 WidgetAPI: Starting token refresh...")
        let url = URL(string: tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("❌ WidgetAPI: Token refresh failed with status \(statusCode)")
            throw MinutAuthError.refreshFailed("Token refresh failed")
        }

        let tokenResponse = try JSONDecoder().decode(MinutTokenResponse.self, from: data)

        return MinutCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }
    
    // MARK: - API Calls

    func getAlarmStatus(homeId: String, accessToken: String) async throws -> AlarmInfo {
        logger.info("📡 WidgetAPI: Getting alarm status for home \(homeId)")
        let url = URL(string: "\(baseURL)/homes/\(homeId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("❌ WidgetAPI: Get alarm status failed with status \(statusCode)")
            throw MinutAPIError.serverError(statusCode)
        }

        logger.info("✅ WidgetAPI: Received alarm status response")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let homeResponse = try decoder.decode(MinutHomeResponse.self, from: data)
        let earliest = homeResponse.alarm.gracePeriodExpiresAt?.ISO8601Format() ?? "unknown"
        logger.info("✅ WidgetAPI: Decoded alarm status: \(homeResponse.alarm.alarmStatus.rawValue), time: \(earliest)")
        return homeResponse.alarm
    }

    func setAlarmStatus(homeId: String, enabled: Bool, accessToken: String) async throws {
        logger.info("📡 WidgetAPI: Setting alarm status to \(enabled ? "ON" : "OFF") for home \(homeId)")
        let url = URL(string: "\(baseURL)/homes/\(homeId)/alarm")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = MinutAlarmUpdateRequest(
            alarmStatus: enabled ? .on : .off,
            alarmMode: .manual,
            silentAlarm: false,
            scheduledAlarmActive: false
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("❌ WidgetAPI: Set alarm status failed with status \(statusCode)")
            throw MinutAPIError.serverError(statusCode)
        }

        logger.info("✅ WidgetAPI: Successfully set alarm status")
    }
}
