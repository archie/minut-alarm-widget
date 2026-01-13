// SharedSettings.swift
// Shared settings between main app and widget extension using App Group

import Foundation

struct SharedSettings {
    
    // IMPORTANT: This must match the App Group ID configured in:
    // 1. Apple Developer Portal
    // 2. Main app entitlements
    // 3. Widget extension entitlements
    static let suiteName = "group.se.akacian.minut-alarm"
    static let clientId = Secrets.clientId
    static let clientSecret = Secrets.clientSecret
    static let redirectUri = "minutalarm://callback"
    
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    
    // MARK: - Selected Home
    
    static var homeId: String {
        get {
            defaults?.string(forKey: Keys.homeId) ?? ""
        }
        set {
            defaults?.set(newValue, forKey: Keys.homeId)
        }
    }
    
    static var homeName: String {
        get {
            defaults?.string(forKey: Keys.homeName) ?? ""
        }
        set {
            defaults?.set(newValue, forKey: Keys.homeName)
        }
    }
    
    // MARK: - Last Known State (for widget offline display)
    
    static var lastKnownAlarmState: Bool {
        get {
            defaults?.bool(forKey: Keys.lastAlarmState) ?? false
        }
        set {
            defaults?.set(newValue, forKey: Keys.lastAlarmState)
        }
    }
    
    static var lastUpdateTime: Date? {
        get {
            defaults?.object(forKey: Keys.lastUpdateTime) as? Date
        }
        set {
            defaults?.set(newValue, forKey: Keys.lastUpdateTime)
        }
    }
    
    // MARK: - Keys
    
    private enum Keys {
        static let homeId = "selectedHomeId"
        static let homeName = "selectedHomeName"
        static let lastAlarmState = "lastKnownAlarmState"
        static let lastUpdateTime = "lastUpdateTime"
    }
    
    // MARK: - Clear All
    
    static func clearAll() {
        defaults?.removeObject(forKey: Keys.homeId)
        defaults?.removeObject(forKey: Keys.homeName)
        defaults?.removeObject(forKey: Keys.lastAlarmState)
        defaults?.removeObject(forKey: Keys.lastUpdateTime)
    }
}
