# Minut Alarm Widget

An iOS app with a home screen widget for controlling Minut home alarms.

## Project Purpose

This app provides a convenient way to arm and disarm Minut home security alarms directly from the iOS home screen. Instead of opening the Minut app, users can tap a widget button to toggle their alarm status.

**Key features:**
- OAuth2 authentication with Minut accounts
- Home selection for users with multiple properties
- Interactive home screen widget (iOS 17+)
- Live countdown timer during alarm arming grace period
- Offline fallback showing cached alarm state

**Intended users:** Minut home alarm owners who want quick access to arm/disarm controls.

## How It Works

### Architecture

The project uses a two-target architecture with a main app and widget extension running in separate processes:

```
┌─────────────────────────┐      ┌──────────────────────────┐
│      Main App           │      │    Widget Extension      │
├─────────────────────────┤      ├──────────────────────────┤
│ MinutAuthService        │      │ WidgetAPIService         │
│ (OAuth2 flow)           │      │ (API calls only)         │
│                         │      │                          │
│ MinutAPIService         │      │ AlarmWidgetProvider      │
│ (Full API access)       │      │ (Timeline management)    │
└───────────┬─────────────┘      └────────────┬─────────────┘
            │                                 │
            ▼                                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    Shared Resources                         │
├─────────────────────────────────────────────────────────────┤
│ Keychain (MinutCredentials: access token, refresh token)    │
│ App Group UserDefaults (selected home ID, cached state)     │
│ MinutNetworkClient (HTTP client, token refresh)             │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Authentication**: Main app handles OAuth2 via `ASWebAuthenticationSession`, stores tokens in Keychain
2. **Home Selection**: User selects a home, ID saved to App Group UserDefaults
3. **Widget Updates**: Widget timeline provider reads shared data, fetches alarm status from API
4. **Token Refresh**: Both targets automatically refresh tokens when expiring (< 5 minutes remaining)
5. **Alarm Toggle**: Widget buttons call `PATCH /homes/{id}/alarm` via `WidgetAPIService`

### External Dependencies

- **Minut API** (`api.minut.com/v8`): OAuth2 endpoints, home/alarm status endpoints
- **App Groups**: Cross-process data sharing between app and widget
- **Keychain Services**: Secure credential storage

No external packages or CocoaPods are used. Pure native Swift with iOS frameworks.

## Getting Started

### Prerequisites

- macOS with Xcode 15.0+
- iOS 17.0+ device or simulator (iOS 16 works with limited widget interactivity)
- Apple Developer account (for App Groups capability)
- Minut account with API access

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd alarm-widget
   ```

2. Open the project:
   ```bash
   open MinutAlarmWidget.xcodeproj
   ```

### Configuration

#### 1. Set up OAuth credentials

Create the secrets file from the template:
```bash
cp Shared/Secrets.swift.template Shared/Secrets.swift
```

Edit `Shared/Secrets.swift` with your Minut API credentials:
```swift
enum Secrets {
    static let clientId = "YOUR_CLIENT_ID"
    static let clientSecret = "YOUR_CLIENT_SECRET"
}
```

To obtain credentials:
1. Go to [api.minut.com](https://api.minut.com) and sign in
2. Create a new API client with redirect URI: `minutalarm://callback`
3. Copy the Client ID and Client Secret

> `Secrets.swift` is gitignored to prevent credential exposure.

#### 2. Configure App Group

The App Group ID `group.se.akacian.minut-alarm` must be registered:

1. In [Apple Developer Portal](https://developer.apple.com), create an App Group identifier
2. In Xcode, add the **App Groups** capability to both targets:
   - MinutAlarmWidget
   - MinutAlarmWidgetExtension

If using a different App Group ID, update:
- `Shared/SharedSettings.swift` line 12
- `Shared/KeychainHelper.swift` lines 10-11

#### 3. Update Bundle Identifiers

If using different bundle identifiers:
1. Update target settings in Xcode
2. Update corresponding entitlement files

### Running the App

1. Select your target device (physical device recommended for widget testing)
2. Build and run the **MinutAlarmWidget** scheme
3. Sign in with your Minut account
4. Select a home from the list

### Adding the Widget

1. Long-press on the iOS home screen
2. Tap the **+** button
3. Search for "Minut Alarm"
4. Select widget size and tap **Add Widget**

## Usage

### Common Workflows

**Arming the alarm:**
- Tap the arm button on the widget
- A countdown timer displays during the grace period
- Tap again to cancel during grace period

**Disarming the alarm:**
- Tap the disarm button on the widget
- Status updates immediately

**Switching homes:**
- Open the main app
- Select a different home from the list
- Widget updates automatically

### Widget States

| State | Description |
|-------|-------------|
| Ready | Shows arm/disarm button based on current status |
| Grace Period | Countdown timer with cancel option |
| Loading | Spinner during API calls |
| Not Authenticated | Prompts to open app and sign in |
| No Home Selected | Prompts to open app and select home |
| Error | Shows cached state with error indicator |

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v8/oauth/authorize` | GET | OAuth authorization |
| `/v8/oauth/token` | POST | Token exchange and refresh |
| `/v8/homes` | GET | List user's homes |
| `/v8/homes/{id}` | GET | Get alarm status |
| `/v8/homes/{id}/alarm` | PATCH | Set alarm status |

## Development

### Project Structure

```
alarm-widget/
├── MinutAlarmWidget/                 # Main app target
│   ├── MinutAlarmWidgetApp.swift     # App entry point
│   ├── ContentView.swift             # Home selection UI
│   ├── SignInView.swift              # OAuth sign-in screen
│   └── Services/
│       ├── MinutAuthService.swift    # OAuth2 flow
│       └── MinutAPIService.swift     # API wrapper
│
├── MinutAlarmWidgetExtension/        # Widget extension target
│   ├── WidgetBundle.swift            # Widget entry point
│   ├── MinutAlarmWidget.swift        # Widget UI and timeline
│   └── WidgetAPIService.swift        # Widget API wrapper
│
└── Shared/                           # Code compiled into both targets
    ├── MinutNetworkClient.swift      # HTTP client
    ├── SharedModels.swift            # Data models
    ├── SharedSettings.swift          # App Group UserDefaults
    ├── KeychainHelper.swift          # Keychain access
    ├── MinutColors.swift             # Brand colors
    └── Secrets.swift                 # OAuth credentials (gitignored)
```

### Build Commands

```bash
# Open in Xcode
open MinutAlarmWidget.xcodeproj

# Build from command line
xcodebuild -scheme MinutAlarmWidget \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

### Logging

Uses `os.log` with subsystem `group.se.akacian.minut-alarm`. Filter in Console.app by:
- "Network" for API calls
- "Widget" for timeline updates
- "Auth" for authentication flow

### Adding Shared Code

When adding new shared files:
1. Create the file in the `Shared/` directory
2. In Xcode, select the file and check both targets in Target Membership

### Brand Colors

Defined in `Shared/MinutColors.swift`:
- `minutContrast` (#1C1A27) - Dark elements
- `minutAction` (#F8C200) - Primary actions
- `minutClarity` (#BACDDF) - Secondary backgrounds
- `minutCalm` (#F8F5F1) - Light text

## Operations and Limitations

### Widget Refresh Behavior

- Normal refresh: every 15 minutes (controlled by iOS)
- During grace period: refreshes 3 seconds after expiry
- iOS may delay updates due to background budget limits
- Force refresh with `WidgetCenter.shared.reloadTimelines(ofKind:)`

### Known Limitations

**Widget process constraints:**
- Cannot present UI or alerts
- Cannot initiate OAuth flow (user must sign in via main app)
- Strict CPU/memory limits
- No access to URL schemes for deep linking

**Simulator limitations:**
- Keychain access groups may not work reliably
- Code disables access groups on simulator automatically
- Test on physical device for production behavior

### Troubleshooting

**"Sign In Required" in widget:**
- Open main app and sign in
- Verify App Group is configured for both targets
- Check keychain access group matches in entitlements

**Widget not updating:**
- Ensure a home is selected in main app
- Pull down on home screen to refresh
- Check Console.app for error logs

**OAuth redirect failing:**
- Verify redirect URI matches exactly: `minutalarm://callback`
- Check URL scheme in `MinutAlarmWidget/Info.plist`
- Ensure configured in Minut developer portal

**Keychain error -34018:**
- Expected on simulator; test on physical device
- Code automatically handles simulator fallback

### Security Notes

- OAuth credentials gitignored in `Secrets.swift`
- Tokens stored encrypted in Keychain with App Group access
- Bearer token authentication for all API calls
- Sensitive data marked `.private` in logs

## License

MIT License
