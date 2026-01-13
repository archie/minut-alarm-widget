// WidgetAPIService.swift
// API service wrapper for widget extension

import Foundation

class WidgetAPIService {
    static let shared = WidgetAPIService()

    private let client = MinutNetworkClient.shared

    private init() {}

    // MARK: - Token Management

    func getValidAccessToken() async throws -> String {
        try await client.getValidAccessToken()
    }

    // MARK: - Alarm

    func getAlarmStatus(homeId: String, accessToken: String) async throws -> AlarmInfo {
        try await client.getAlarmStatus(homeId: homeId, accessToken: accessToken)
    }

    func setAlarmStatus(homeId: String, enabled: Bool, accessToken: String) async throws {
        try await client.setAlarmStatus(homeId: homeId, enabled: enabled, accessToken: accessToken)
    }
}
