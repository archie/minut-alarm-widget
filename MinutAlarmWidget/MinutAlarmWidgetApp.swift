// MinutAlarmWidgetApp.swift
// Main app entry point

import SwiftUI

@main
struct MinutAlarmWidgetApp: App {
    
    init() {
        // Configure the auth service on launch
        MinutAuthService.shared.configure(
            clientId: SharedSettings.clientId,
            clientSecret: SharedSettings.clientSecret,
            redirectUri: SharedSettings.redirectUri
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
