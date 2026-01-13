# Minut Alarm Widget

An iOS app and widget for controlling your Minut home alarm from your home screen.

## Features

- **OAuth2 Authentication** - Secure sign-in with your Minut account
- **Home Selection** - Choose which home to control
- **Home Screen Widget** - Arm/disarm your alarm without opening the app
- **Interactive Widget** - iOS 17+ support for direct button taps
- **Grace Period Support** - Live countdown timer when alarm is arming
- **Brand Colors** - Minut's official brand colors throughout the UI
- **Offline Fallback** - Shows cached state when network is unavailable

## Setup Instructions

### 1. Get Minut API Credentials

1. Go to [api.minut.com](https://api.minut.com) and sign in
2. Navigate to the API Client dashboard
3. Create a new client with:
   - **Name**: Your app name (e.g., "My Alarm Widget")
   - **Redirect URI**: `minutalarm://callback`
4. Save your **Client ID** and **Client Secret**

### 2. Configure OAuth Credentials

1. Open the project in Xcode
2. Copy the secrets template:
   ```bash
   cp Shared/Secrets.swift.template Shared/Secrets.swift
   ```
3. Edit `Shared/Secrets.swift` and add your credentials:
   ```swift
   enum Secrets {
       static let clientId = "YOUR_CLIENT_ID"
       static let clientSecret = "YOUR_CLIENT_SECRET"
   }
   ```
4. Add `Secrets.swift` to both targets in Xcode:
   - MinutAlarmWidget
   - MinutAlarmWidgetExtension

> **Note:** `Secrets.swift` is gitignored to prevent credentials from being committed.

### 3. Configure App Group (Required for Widget)

The app group allows data sharing between the main app and widget extension.

1. Sign in to [Apple Developer Portal](https://developer.apple.com)
2. Go to **Certificates, Identifiers & Profiles** → **Identifiers**
3. Create a new **App Group** with ID: `group.se.akacian.minut-alarm` (or your own)
4. In Xcode:
   - Select the **MinutAlarmWidget** target → **Signing & Capabilities**
   - Add **App Groups** capability and select your group
   - Repeat for **MinutAlarmWidgetExtension** target

If using a different App Group ID, update it in:
- `Shared/SharedSettings.swift` (line 12)
- `Shared/KeychainHelper.swift` (lines 10-11)

### 4. Update Bundle Identifiers

1. In Xcode, select each target and update:
   - **MinutAlarmWidget**: `se.akacian.minut-alarm-widget` (or your own)
   - **MinutAlarmWidgetExtension**: `se.akacian.minut-alarm-widget.Widget`
2. Update the entitlements files to match:
   - `MinutAlarmWidget/MinutAlarmWidget.entitlements`
   - `MinutAlarmWidgetExtension/MinutAlarmWidgetExtension.entitlements`

### 5. Build and Run

1. Select your target device or simulator (iOS 17+ recommended)
2. Build and run the main app first
3. Sign in with your Minut account
4. Select a home from the list
5. Add the widget to your home screen:
   - Long press on home screen
   - Tap the + button
   - Search for "Minut Alarm"
   - Choose widget size and tap "Add Widget"

## Project Structure

```
alarm-widget/
├── MinutAlarmWidget/              # Main iOS app
│   ├── MinutAlarmWidgetApp.swift  # App entry point
│   ├── ContentView.swift          # Main UI with home selection
│   ├── SignInView.swift           # OAuth sign-in screen
│   └── Services/
│       ├── MinutAuthService.swift # OAuth2 flow (143 lines)
│       └── MinutAPIService.swift  # API wrapper (28 lines)
│
├── MinutAlarmWidgetExtension/     # Widget extension
│   ├── WidgetBundle.swift         # Widget entry point
│   ├── MinutAlarmWidget.swift     # Widget UI & timeline provider
│   └── WidgetAPIService.swift     # Widget API wrapper (28 lines)
│
└── Shared/                        # Shared code (both targets)
    ├── MinutNetworkClient.swift   # Centralized networking (247 lines)
    ├── SharedModels.swift         # Data models & API responses
    ├── SharedSettings.swift       # App Group UserDefaults
    ├── KeychainHelper.swift       # Secure credential storage
    ├── MinutColors.swift          # Minut brand colors
    ├── Secrets.swift              # OAuth credentials (gitignored)
    └── Secrets.swift.template     # Template for credentials
```

## Architecture

### Networking Layer

All HTTP operations flow through `MinutNetworkClient`:
- Token exchange and refresh
- API request handling
- Error handling
- Comprehensive logging

Both `MinutAPIService` and `WidgetAPIService` are thin wrappers that delegate to the shared network client, eliminating code duplication.

### Authentication

- OAuth2 authorization code flow
- Tokens stored securely in Keychain with App Group access
- Automatic token refresh when expiring (< 5 minutes remaining)
- Widget can refresh tokens independently

### Widget Timeline

- Refreshes every 15 minutes normally
- During grace period: refreshes 3 seconds after expiry
- Shows cached state when offline or on error
- Distinct states: ready, loading, not authenticated, no home selected, error

## API Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v8/oauth/authorize` | GET | OAuth authorization |
| `/v8/oauth/token` | POST | Token exchange & refresh |
| `/v8/homes` | GET | List user's homes |
| `/v8/homes/{id}` | GET | Get home details & alarm status |
| `/v8/homes/{id}/alarm` | PATCH | Set alarm status |

## Brand Colors

The app uses Minut's official brand colors:

- **Contrast** (#1C1A27) - Dark UI elements, buttons
- **Action** (#F8C200) - Primary actions, highlights
- **Clarity** (#BACDDF) - Secondary backgrounds
- **Calm** (#F8F5F1) - Text on dark backgrounds

Colors are defined in `Shared/MinutColors.swift` and used throughout both the app and widget.

## Troubleshooting

### "Sign In Required" in Widget
- Open the main app and sign in
- Verify App Group is configured correctly for both targets
- Check that credentials are in the Keychain (sign in again if needed)

### Widget Not Updating
- Ensure a home is selected in the main app
- Pull down on home screen to refresh widgets
- Check Console.app for logs (filter by "Widget" or "Network")

### OAuth Redirect Failing
- Verify redirect URI matches exactly: `minutalarm://callback`
- Check URL scheme is in `Info.plist`
- Ensure it's configured in Minut developer portal

### Keychain Error -34018 (Simulator)
- This is expected on simulator - keychain access groups don't work reliably
- Code automatically disables access groups on simulator
- Test on physical device for production behavior

### Widget Shows Cached State
- Widget falls back to cached state when API fails
- Look for error indicator (orange exclamation mark)
- Check network connectivity
- Verify credentials haven't expired

## Development

### Adding New Features

1. **API Changes**: Update `MinutNetworkClient.swift`
2. **Models**: Update `SharedModels.swift`
3. **UI**: Update view files in respective targets
4. **Widget**: Update `MinutAlarmWidget.swift`

### Logging

Comprehensive logging using `os.log`:
- **Network**: Token refresh, API calls, errors
- **Widget**: Timeline updates, state changes, grace period
- **Auth**: Sign-in flow, token management

Filter Console.app by subsystem: `group.se.akacian.minut-alarm`

### Code Review

See `code_review.md` for detailed analysis and recommendations.

## Security Notes

- OAuth credentials stored in `Secrets.swift` (gitignored)
- Tokens encrypted in Keychain with App Group access
- All API calls use Bearer token authentication
- Privacy-aware logging (sensitive data marked `.private`)
- Simulator keychain workaround for development

## Requirements

- iOS 17.0+ (for interactive widget buttons)
- iOS 16.0+ (with deep link fallback for older versions)
- Xcode 15.0+
- Swift 5.9+
- Minut account with API access
- Apple Developer account (for App Groups)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run code review: see `code_review.md` for guidelines
5. Submit a pull request

## License

MIT License
