// MinutAuthService.swift
// OAuth2 authentication service for Minut API

import Foundation
import AuthenticationServices

// MARK: - OAuth Configuration

struct MinutOAuthConfig {
    let clientId: String
    let clientSecret: String
    let redirectUri: String
    
    static let authorizationEndpoint = "https://api.minut.com/v8/oauth/authorize"
    static let tokenEndpoint = "https://api.minut.com/v8/oauth/token"
}

// MARK: - Auth Service

@MainActor
class MinutAuthService: NSObject, ObservableObject {
    
    static let shared = MinutAuthService()
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: MinutAuthError?
    
    private var config: MinutOAuthConfig?
    private var authSession: ASWebAuthenticationSession?
    
    override init() {
        super.init()
        if let credentials = KeychainHelper.loadCredentials() {
            isAuthenticated = !credentials.isExpired
        }
    }
    
    // MARK: - Configuration
    
    func configure(clientId: String, clientSecret: String, redirectUri: String) {
        self.config = MinutOAuthConfig(
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUri: redirectUri
        )
    }
    
    // MARK: - Sign In
    
    func signIn(presentingFrom contextProvider: ASWebAuthenticationPresentationContextProviding) async throws {
        guard let config = config else {
            throw MinutAuthError.invalidConfiguration
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Build authorization URL
        var components = URLComponents(string: MinutOAuthConfig.authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "state", value: generateState())
        ]
        
        guard let authURL = components.url else {
            throw MinutAuthError.invalidConfiguration
        }
        
        guard let callbackScheme = URL(string: config.redirectUri)?.scheme else {
            throw MinutAuthError.invalidConfiguration
        }
        
        // Perform OAuth flow
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    if case ASWebAuthenticationSessionError.canceledLogin = error {
                        continuation.resume(throwing: MinutAuthError.authorizationFailed("User cancelled"))
                    } else {
                        continuation.resume(throwing: MinutAuthError.authorizationFailed(error.localizedDescription))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: MinutAuthError.authorizationFailed("No callback URL"))
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false
            
            self.authSession = session
            session.start()
        }
        
        // Extract authorization code
        guard let code = extractAuthorizationCode(from: callbackURL) else {
            throw MinutAuthError.authorizationFailed("No authorization code in callback")
        }
        
        // Exchange code for tokens
        let credentials = try await exchangeCodeForTokens(code: code)
        
        // Store credentials
        try KeychainHelper.saveCredentials(credentials)
        isAuthenticated = true
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        KeychainHelper.deleteCredentials()
        isAuthenticated = false
    }
    
    // MARK: - Get Valid Token
    
    func getValidAccessToken() async throws -> String {
        guard var credentials = KeychainHelper.loadCredentials() else {
            throw MinutAuthError.missingCredentials
        }
        
        // Refresh if expiring within 5 minutes
        if credentials.isExpiringSoon {
            credentials = try await refreshTokens(refreshToken: credentials.refreshToken)
            try KeychainHelper.saveCredentials(credentials)
        }
        
        return credentials.accessToken
    }
    
    // MARK: - Token Exchange
    
    private func exchangeCodeForTokens(code: String) async throws -> MinutCredentials {
        guard let config = config else {
            throw MinutAuthError.invalidConfiguration
        }
        
        let url = URL(string: MinutOAuthConfig.tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "redirect_uri": config.redirectUri
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinutAuthError.invalidResponse
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MinutAuthError.tokenExchangeFailed("Status \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let tokenResponse = try JSONDecoder().decode(MinutTokenResponse.self, from: data)
        
        return MinutCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }
    
    // MARK: - Token Refresh
    
    private func refreshTokens(refreshToken: String) async throws -> MinutCredentials {
        guard let config = config else {
            throw MinutAuthError.invalidConfiguration
        }
        
        let url = URL(string: MinutOAuthConfig.tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientId,
            "client_secret": config.clientSecret
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinutAuthError.invalidResponse
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 400 {
                KeychainHelper.deleteCredentials()
                await MainActor.run { isAuthenticated = false }
            }
            
            throw MinutAuthError.refreshFailed("Status \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let tokenResponse = try JSONDecoder().decode(MinutTokenResponse.self, from: data)
        
        return MinutCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }
    
    // MARK: - Helpers
    
    private func extractAuthorizationCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }
    
    private func generateState() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<32).map { _ in characters.randomElement()! })
    }
}

// MARK: - Presentation Context Provider

class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
