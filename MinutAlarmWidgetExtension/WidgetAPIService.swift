// WidgetAPIService.swift
// Lightweight API service for the widget extension

import Foundation

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
        guard var credentials = KeychainHelper.loadCredentials() else {
            throw MinutAuthError.missingCredentials
        }
        
        // Refresh if expiring within 5 minutes
        if credentials.isExpiringSoon {
            credentials = try await refreshToken(credentials.refreshToken)
            try KeychainHelper.saveCredentials(credentials)
        }
        
        return credentials.accessToken
    }
    
    private func refreshToken(_ refreshToken: String) async throws -> MinutCredentials {
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
    
    func getAlarmStatus(homeId: String, accessToken: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/homes/\(homeId)/alarm")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw MinutAPIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        print(data)
    
        let alarmResponse = try JSONDecoder().decode(MinutAlarmResponse.self, from: data)
        //return alarmResponse.alarm.enabled
        return true // fixme
    }
    
    func setAlarmStatus(homeId: String, enabled: Bool, accessToken: String) async throws {
        let url = URL(string: "\(baseURL)/homes/\(homeId)/alarm")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "alarm_status": enabled ? "on" : "off"
        ]

        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw MinutAPIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}
