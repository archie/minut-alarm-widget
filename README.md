# Minut Alarm Widget

An iOS app and widget for controlling your Minut home alarm.

## Features

- **OAuth2 Authentication** - Secure sign-in with your Minut account
- **Home Selection** - Choose which home to control
- **Home Screen Widget** - Arm/disarm your alarm without opening the app
- **Interactive Widget** - iOS 17+ support for direct button taps

## Setup Instructions

### 1. Get Minut API Credentials

1. Go to [api.minut.com](https://api.minut.com) and sign in
2. Navigate to the API Client dashboard
3. Create a new client with:
   - **Name**: Your app name (e.g., "My Alarm Widget")
   - **Redirect URI**: `minutalarm://callback`
4. Save your **Client ID** and **Client Secret**

### 2. Configure the Project

1. Open `MinutAlarmWidget.xcodeproj` in Xcode
2. Update your credentials in `MinutAlarmWidgetApp.swift`:
   ```swift
   enum Configuration {
       static let clientId = "YOUR_CLIENT_ID"
       static let clientSecret = "YOUR_CLIENT_SECRET"
       static let redirectUri = "minutalarm://callback"
   }
   ```
3. Also update the same credentials in `MinutAlarmWidgetExtension/WidgetAPIService.swift`

### 3. Configure App Group (Required for Widget)

1. Sign in to [Apple Developer Portal](https://developer.apple.com)
2. Go to **Certificates, Identifiers & Profiles** → **Identifiers**
3. Create a new **App Group** with ID: `group.com.yourcompany.MinutAlarmWidget`
4. In Xcode:
   - Select the **MinutAlarmWidget** target → **Signing & Capabilities**
   - Add **App Groups** capability and select your group
   - Repeat for **MinutAlarmWidgetExtension** target

### 4. Update Bundle Identifiers

1. In Xcode, select each target and update:
   - **MinutAlarmWidget**: `com.yourcompany.MinutAlarmWidget`
   - **MinutAlarmWidgetExtension**: `com.yourcompany.MinutAlarmWidget.Widget`
2. Update the App Group ID in these files to match:
   - `Shared/SharedSettings.swift`
   - `Shared/KeychainHelper.swift`
   - `MinutAlarmWidget/MinutAlarmWidget.entitlements`
   - `MinutAlarmWidgetExtension/MinutAlarmWidgetExtension.entitlements`

### 5. Build and Run

1. Select your target device or simulator (iOS 17+ recommended)
2. Build and run the main app first
3. Sign in with your Minut account
4. Select a home
5. Add the widget to your home screen

## Project Structure

```
MinutAlarmWidget/
├── MinutAlarmWidget/              # Main app
│   ├── MinutAlarmWidgetApp.swift  # App entry point
│   ├── ContentView.swift          # Main UI
│   ├── SignInView.swift           # Sign-in UI
│   ├── Services/
│   │   ├── MinutAuthService.swift # OAuth2 authentication
│   │   └── MinutAPIService.swift  # API calls
│   └── Assets.xcassets/
│
├── MinutAlarmWidgetExtension/     # Widget extension
│   ├── WidgetBundle.swift         # Widget entry point
│   ├── MinutAlarmWidget.swift     # Widget UI & logic
│   ├── WidgetAPIService.swift     # Lightweight API for widget
│   └── WidgetAssets.xcassets/
│
└── Shared/                        # Shared code (both targets)
    ├── SharedModels.swift         # Data models
    ├── SharedSettings.swift       # App Group UserDefaults
    └── KeychainHelper.swift       # Secure credential storage
```

## API Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v8/oauth/authorize` | GET | OAuth authorization |
| `/v8/oauth/token` | POST | Token exchange & refresh |
| `/v8/homes` | GET | List user's homes |
| `/v8/homes/{id}/alarm` | GET | Get alarm status |
| `/v8/homes/{id}/alarm` | PATCH | Set alarm status |

## Troubleshooting

### "Sign In Required" in Widget
- Open the main app and sign in
- Verify App Group is configured for both targets

### Widget Not Updating
- Check that the home is selected in the main app
- Pull down on home screen to refresh widgets
- Check Console.app for widget logs

### OAuth Redirect Failing
- Verify redirect URI matches exactly: `minutalarm://callback`
- Check URL scheme is in Info.plist

## Requirements

- iOS 17.0+ (for interactive widget buttons)
- iOS 16.0+ (with deep link fallback)
- Xcode 15.0+
- Minut account with API access

## License

MIT License
