// MinutAPIService.swift
// API service for Minut alarm operations

import Foundation

// MARK: - API Service

class MinutAPIService {
    static let shared = MinutAPIService()
    
    private let baseURL = "https://api.minut.com/v8"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Homes
    
    func getHomes(accessToken: String) async throws -> [MinutHome] {
        let url = URL(string: "\(baseURL)/homes")!
        let data = try await performRequest(url: url, method: "GET", accessToken: accessToken)
        
        let response = try JSONDecoder().decode(MinutHomesResponse.self, from: data)
        return response.homes
    }
    
    // MARK: - Alarm
    
    func getAlarmStatus(homeId: String, accessToken: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/homes/\(homeId)/alarm")!
        let data = try await performRequest(url: url, method: "GET", accessToken: accessToken)
        
        let response = try JSONDecoder().decode(MinutAlarmResponse.self, from: data)
        return response.alarm.enabled
    }
    
    func setAlarmStatus(homeId: String, enabled: Bool, accessToken: String) async throws {
        let url = URL(string: "\(baseURL)/homes/\(homeId)/alarm")!
        
        let requestBody = MinutAlarmUpdateRequest(
            alarm: MinutAlarmUpdateRequest.AlarmUpdate(enabled: enabled)
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        
        _ = try await performRequest(
            url: url,
            method: "PATCH",
            accessToken: accessToken,
            body: bodyData
        )
    }
    
    // MARK: - Private Helpers
    
    private func performRequest(
        url: URL,
        method: String,
        accessToken: String,
        body: Data? = nil
    ) async throws -> Data {
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
            throw MinutAPIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinutAPIError.unknown
        }
        
        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            throw MinutAPIError.unauthorized
        case 403:
            throw MinutAPIError.forbidden
        case 404:
            throw MinutAPIError.notFound
        default:
            throw MinutAPIError.serverError(httpResponse.statusCode)
        }
    }
}
