// ContentView.swift
// Main content view that switches between sign-in and authenticated states

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = MinutAuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                AuthenticatedHomeView()
            } else {
                SignInView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

// MARK: - Authenticated Home View

struct AuthenticatedHomeView: View {
    @StateObject private var authService = MinutAuthService.shared
    @State private var selectedHomeId: String = ""
    @State private var homes: [MinutHome] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading homes...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Error Loading Homes",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if homes.isEmpty {
                    ContentUnavailableView(
                        "No Homes Found",
                        systemImage: "house.slash",
                        description: Text("No homes are associated with your Minut account.")
                    )
                } else {
                    homesList
                }
            }
            .navigationTitle("Minut Alarm")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        authService.signOut()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await loadHomes() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadHomes()
            }
        }
    }
    
    private var homesList: some View {
        List {
            Section("Select a Home for Widget") {
                ForEach(homes) { home in
                    HomeRowView(
                        home: home,
                        isSelected: home.id == selectedHomeId
                    ) {
                        selectedHomeId = home.id
                        SharedSettings.homeId = home.id
                    }
                }
            }
            
            if !selectedHomeId.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Widget Ready!", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.minutAction)
                            .font(.headline)
                        
                        Text("Add the Minut Alarm widget to your home screen:")
                            .font(.subheadline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Long press on your home screen")
                            Text("2. Tap the + button")
                            Text("3. Search for \"Minut Alarm\"")
                            Text("4. Choose widget size and tap \"Add Widget\"")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private func loadHomes() async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let token = try await authService.getValidAccessToken()
            homes = try await MinutAPIService.shared.getHomes(accessToken: token)
            
            // Restore previously selected home if still valid
            let savedHomeId = SharedSettings.homeId
            if !savedHomeId.isEmpty && homes.contains(where: { $0.id == savedHomeId }) {
                selectedHomeId = savedHomeId
            } else if let firstHome = homes.first {
                // Auto-select first home if none selected
                selectedHomeId = firstHome.id
                SharedSettings.homeId = firstHome.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Home Row View

struct HomeRowView: View {
    let home: MinutHome
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(home.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let timezone = home.timezone {
                        Text(timezone)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.minutAction)
                        .font(.title2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Authenticated") {
    ContentView()
}
