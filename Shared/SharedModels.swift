// SharedModels.swift
// Models shared between main app and widget extension

import Foundation

// MARK: - Auth Errors

enum MinutAuthError: LocalizedError {
    case missingCredentials
    case invalidConfiguration
    case authorizationFailed(String)
    case tokenExchangeFailed(String)
    case refreshFailed(String)
    case networkError(Error)
    case invalidResponse
    case keychainError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "No stored credentials found. Please sign in."
        case .invalidConfiguration:
            return "OAuth configuration is invalid."
        case .authorizationFailed(let reason):
            return "Authorization failed: \(reason)"
        case .tokenExchangeFailed(let reason):
            return "Token exchange failed: \(reason)"
        case .refreshFailed(let reason):
            return "Token refresh failed: \(reason)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
}

// MARK: - API Errors

enum MinutAPIError: LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        case .forbidden:
            return "Access forbidden to this resource."
        case .notFound:
            return "Resource not found."
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

// MARK: - Token Response

struct MinutTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Credentials

struct MinutCredentials: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
    var isExpired: Bool {
        Date() >= expiresAt
    }
    
    var isExpiringSoon: Bool {
        // Consider token expiring if less than 5 minutes remain
        Date().addingTimeInterval(300) >= expiresAt
    }
}

// MARK: - Home

struct MinutHome: Identifiable, Codable {
    let id: String
    let name: String
    let timezone: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "home_id"
        case name
        case timezone
    }
}

// MARK: - API Response Models

struct MinutHomesResponse: Codable {
    let homes: [MinutHome]
}

struct MinutAlarmResponse: Codable {
    let alarm: AlarmState
    
    struct AlarmState: Codable {
        let enabled: Bool
        let mode: String?
    }
}

struct MinutAlarmUpdateRequest: Codable {
    let alarm: AlarmUpdate
    
    struct AlarmUpdate: Codable {
        let enabled: Bool
    }
}

// MARK: - Alarm Status (for local use)

struct AlarmStatus {
    let isArmed: Bool
    let mode: String?
    let lastUpdated: Date
    
    init(isArmed: Bool, mode: String? = nil) {
        self.isArmed = isArmed
        self.mode = mode
        self.lastUpdated = Date()
    }
}
