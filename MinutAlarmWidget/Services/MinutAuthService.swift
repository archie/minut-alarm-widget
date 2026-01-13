// MinutAuthService.swift
// OAuth2 authentication service for Minut API

import Foundation
import AuthenticationServices

// MARK: - Auth Service

@MainActor
class MinutAuthService: NSObject, ObservableObject {

    static let shared = MinutAuthService()

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: MinutAuthError?

    private let client = MinutNetworkClient.shared
    private var authSession: ASWebAuthenticationSession?

    private static let authorizationEndpoint = "https://api.minut.com/v8/oauth/authorize"

    override init() {
        super.init()
        if let credentials = KeychainHelper.loadCredentials() {
            isAuthenticated = !credentials.isExpired
        }
    }

    // MARK: - Sign In

    func signIn(presentingFrom contextProvider: ASWebAuthenticationPresentationContextProviding) async throws {
        isLoading = true
        defer { isLoading = false }

        // Build authorization URL
        var components = URLComponents(string: Self.authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: SharedSettings.clientId),
            URLQueryItem(name: "redirect_uri", value: SharedSettings.redirectUri),
            URLQueryItem(name: "state", value: generateState())
        ]

        guard let authURL = components.url else {
            throw MinutAuthError.invalidConfiguration
        }

        guard let callbackScheme = URL(string: SharedSettings.redirectUri)?.scheme else {
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
        let credentials = try await client.exchangeCodeForTokens(code: code)

        // Store credentials
        try KeychainHelper.saveCredentials(credentials)
        isAuthenticated = true
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainHelper.deleteCredentials()
        SharedSettings.clearAll()
        isAuthenticated = false
    }

    // MARK: - Get Valid Token

    func getValidAccessToken() async throws -> String {
        do {
            return try await client.getValidAccessToken()
        } catch {
            // Handle auth failures by updating UI state
            if case MinutAuthError.refreshFailed = error {
                KeychainHelper.deleteCredentials()
                isAuthenticated = false
            }
            throw error
        }
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
