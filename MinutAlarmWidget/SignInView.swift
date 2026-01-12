// SignInView.swift
// Sign-in view for Minut authentication

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var authService = MinutAuthService.shared
    @State private var showError = false
    
    private let contextProvider = AuthPresentationContextProvider()
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App Icon
            ZStack {
                Circle()
                    .fill(Color.minutContrast)
                    .frame(width: 120, height: 120)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.minutAction)
            }
            
            // Title
            VStack(spacing: 8) {
                Text("Minut Alarm")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Control your home alarm from your widget")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "bell.badge",
                    title: "Alarm Status",
                    description: "See if your home is armed or disarmed"
                )
                
                FeatureRow(
                    icon: "hand.tap",
                    title: "Quick Toggle",
                    description: "Arm or disarm with a single tap"
                )
                
                FeatureRow(
                    icon: "rectangle.3.group",
                    title: "Home Screen Widget",
                    description: "Access controls without opening the app"
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Sign In Button
            VStack(spacing: 16) {
                Button(action: signIn) {
                    HStack(spacing: 12) {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                            Text("Sign in with Minut")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.minutContrast)
                    .foregroundColor(.minutCalm)
                    .cornerRadius(14)
                    .font(.headline)
                }
                .disabled(authService.isLoading)
                .padding(.horizontal, 32)
                
                Text("You'll be redirected to Minut to sign in securely")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
                .frame(height: 40)
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authService.error?.localizedDescription ?? "An unknown error occurred")
        }
    }
    
    private func signIn() {
        Task {
            do {
                try await authService.signIn(presentingFrom: contextProvider)
            } catch {
                authService.error = error as? MinutAuthError ?? .authorizationFailed(error.localizedDescription)
                showError = true
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.minutAction)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SignInView()
}
