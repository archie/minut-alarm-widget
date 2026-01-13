// MinutAPIService.swift
// API service wrapper for main app

import Foundation

class MinutAPIService {
    static let shared = MinutAPIService()

    private let client = MinutNetworkClient.shared

    private init() {}

    // MARK: - Homes

    func getHomes(accessToken: String) async throws -> [MinutHome] {
        try await client.getHomes(accessToken: accessToken)
    }

    // MARK: - Alarm

    func getAlarmStatus(homeId: String, accessToken: String) async throws -> AlarmInfo {
        try await client.getAlarmStatus(homeId: homeId, accessToken: accessToken)
    }

    func setAlarmStatus(homeId: String, enabled: Bool, accessToken: String) async throws {
        try await client.setAlarmStatus(homeId: homeId, enabled: enabled, accessToken: accessToken)
    }
}
