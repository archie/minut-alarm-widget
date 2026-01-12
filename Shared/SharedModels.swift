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
    let alarm: AlarmInfo?

    enum CodingKeys: String, CodingKey {
        case id = "home_id"
        case name
        case timezone
        case alarm
    }
}

// MARK: - Alarm Info

struct AlarmInfo: Codable {
    let events: [AlarmEvent]?
    let gracePeriodExpiresAt: Date?
    let gracePeriodSecs: Int?
    let escalationStatus: EscalationStatus?
    let escalatedBy: String?
    let escalationCancelledBy: String?
    let escalationPeriodExpiresAt: Date?
    let escalationPeriodSeconds: Int?
    let earliestAlarmTime: Date?
    let alarmStatus: AlarmStatus
    let alarmMode: AlarmMode?
    let silentAlarm: Bool?
    let scheduledAlarmActive: Bool?

    enum CodingKeys: String, CodingKey {
        case events
        case gracePeriodExpiresAt = "grace_period_expires_at"
        case gracePeriodSecs = "grace_period_secs"
        case escalationStatus = "escalation_status"
        case escalatedBy = "escalated_by"
        case escalationCancelledBy = "escalation_cancelled_by"
        case escalationPeriodExpiresAt = "escalation_period_expires_at"
        case escalationPeriodSeconds = "escalation_period_seconds"
        case earliestAlarmTime = "earliest_alarm_time"
        case alarmStatus = "alarm_status"
        case alarmMode = "alarm_mode"
        case silentAlarm = "silent_alarm"
        case scheduledAlarmActive = "scheduled_alarm_active"
    }

    var isArmed: Bool {
        alarmStatus == .on || alarmStatus == .onGracePeriod
    }
}

struct AlarmEvent: Codable {
    let eventType: String
    let deviceId: String
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case deviceId = "device_id"
        case occurredAt = "occurred_at"
    }
}

enum AlarmStatus: String, Codable {
    case on
    case off
    case offGracePeriod = "off_grace_period"
    case onGracePeriod = "on_grace_period"
    case criticalEvent = "critical_event"
}

enum AlarmMode: String, Codable {
    case manual
}

enum EscalationStatus: String, Codable {
    case none
    case countdown
    case escalatedAutomatically = "escalated_automatically"
    case escalatedManually = "escalated_manually"
    case escalationCancelled = "escalation_cancelled"
}

// MARK: - API Response Models

struct MinutHomesResponse: Codable {
    let homes: [MinutHome]
}

struct MinutHomeResponse: Codable {
    let homeId: String
    let name: String
    let timezone: String?
    let alarmStatus: AlarmStatus?
    let detailedAlarmStatus: String?
    let alarmMode: AlarmMode?
    let scheduledAlarmActive: Bool?
    let silentAlarm: Bool?
    let alarmOffGracePeriodSecs: Int?

    // Additional optional fields from the API
    let createdAt: Date?
    let address: Address?
    let members: [Member]?
    let devices: [Device]?

    enum CodingKeys: String, CodingKey {
        case homeId = "home_id"
        case name
        case timezone
        case alarmStatus = "alarm_status"
        case detailedAlarmStatus = "detailed_alarm_status"
        case alarmMode = "alarm_mode"
        case scheduledAlarmActive = "scheduled_alarm_active"
        case silentAlarm = "silent_alarm"
        case alarmOffGracePeriodSecs = "alarm_off_grace_period_secs"
        case createdAt = "created_at"
        case address
        case members
        case devices
    }

    var alarm: AlarmInfo {
        AlarmInfo(
            events: nil,
            gracePeriodExpiresAt: nil,
            gracePeriodSecs: alarmOffGracePeriodSecs,
            escalationStatus: nil,
            escalatedBy: nil,
            escalationCancelledBy: nil,
            escalationPeriodExpiresAt: nil,
            escalationPeriodSeconds: nil,
            earliestAlarmTime: nil,
            alarmStatus: alarmStatus ?? .off,
            alarmMode: alarmMode,
            silentAlarm: silentAlarm,
            scheduledAlarmActive: scheduledAlarmActive
        )
    }
}

struct Address: Codable {
    let streetName1: String?
    let streetName2: String?
    let postCode: String?
    let city: String?
    let country: String?
    let apartmentNumber: String?
    let floorNumber: String?

    enum CodingKeys: String, CodingKey {
        case streetName1 = "street_name1"
        case streetName2 = "street_name2"
        case postCode = "post_code"
        case city
        case country
        case apartmentNumber = "apartment_number"
        case floorNumber = "floor_number"
    }
}

struct Member: Codable {
    let userId: String?
    let fullname: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullname
        case email
    }
}

struct Device: Codable {
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
    }
}

struct MinutAlarmUpdateRequest: Codable {
    let alarmStatus: AlarmStatus
    let alarmMode: AlarmMode?
    let silentAlarm: Bool?
    let scheduledAlarmActive: Bool?

    enum CodingKeys: String, CodingKey {
        case alarmStatus = "alarm_status"
        case alarmMode = "alarm_mode"
        case silentAlarm = "silent_alarm"
        case scheduledAlarmActive = "scheduled_alarm_active"
    }
}
