# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS app with a home screen widget for controlling Minut home alarms. It uses OAuth2 for authentication and communicates with the Minut API (api.minut.com/v8).

## Build & Development Commands

### Building and Running
```bash
# Open in Xcode
open MinutAlarmWidget.xcodeproj

# Build from command line (requires selecting scheme first in Xcode)
xcodebuild -scheme MinutAlarmWidget -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Note: This is a pure Xcode project with no CocoaPods, SPM packages, or external build tools.

### Testing the Widget
- Build and run the main app first to authenticate
- Long-press on the iOS home screen → Add Widget → Minut Alarm
- Or use Xcode's Widget extension scheme to debug the widget directly

## Configuration Requirements

### OAuth Credentials
Credentials must be updated in TWO locations:
1. `MinutAlarmWidget/MinutAlarmWidgetApp.swift` - Configuration enum (lines 29-33)
2. `MinutAlarmWidgetExtension/WidgetAPIService.swift` - Private constants (lines 13-14)

These MUST match or authentication will fail in the widget.

### App Group Identifier
The App Group ID is defined in `Shared/SharedSettings.swift:12` as `se.akacian.minut-alarm-widget`. This must be:
1. Registered in Apple Developer Portal
2. Added to both target entitlements files
3. Used consistently across all shared storage code

## Architecture

### Two-Target Structure
The app has a dual-target architecture that requires careful data sharing:

**Main App (`MinutAlarmWidget` target)**
- Handles OAuth2 flow using ASWebAuthenticationSession
- Presents UI for home selection
- Stores tokens in keychain and selected home in App Group UserDefaults
- Services: `MinutAuthService` (full OAuth), `MinutAPIService` (full API access)

**Widget Extension (`MinutAlarmWidgetExtension` target)**
- Runs in separate process with limited lifetime
- Reads shared keychain for tokens
- Reads App Group UserDefaults for selected home
- Has lightweight `WidgetAPIService` with only token refresh + alarm endpoints
- Cannot perform OAuth flow (no UI context)

### Critical Shared Resources
All communication between targets happens through:
1. **Keychain** (`KeychainHelper`) - Stores `MinutCredentials` (access token, refresh token, expiry)
2. **App Group UserDefaults** (`SharedSettings`) - Stores selected home ID/name and last known alarm state
3. **Shared Models** (`SharedModels.swift`) - Data structures used by both targets

### Data Flow for Widget Updates
1. Widget timeline provider wakes up (every 15 minutes)
2. Reads `homeId` from `SharedSettings`
3. Gets credentials from `KeychainHelper.loadCredentials()`
4. Checks if token `isExpiringSoon` (< 5 minutes remaining)
5. Refreshes token if needed using widget's `WidgetAPIService`
6. Fetches alarm status from `/v8/homes/{id}/alarm`
7. Caches result in `SharedSettings.lastKnownAlarmState` for offline display
8. Returns `AlarmEntry` with current state

### Token Refresh Strategy
Both the main app and widget implement automatic token refresh:
- Tokens are considered "expiring soon" if < 5 minutes remain (`MinutCredentials.isExpiringSoon`)
- Both `MinutAuthService.getValidAccessToken()` and `WidgetAPIService.getValidAccessToken()` check this
- Refresh happens transparently before any API call
- If refresh fails with 401/400, credentials are deleted and user must re-authenticate in main app

### Interactive Widget Buttons (iOS 17+)
The widget uses `AppIntents` framework for direct button interactions:
- `ToggleAlarmIntent` executes arm/disarm actions
- Runs in widget extension process
- Immediately updates `SharedSettings.lastKnownAlarmState`
- Calls `WidgetCenter.shared.reloadTimelines()` to refresh UI
- For iOS 16, falls back to deep links (`minutalarm://toggle?action=arm`)

## Minut API Integration

### Base URL
`https://api.minut.com/v8`

### Authentication Flow
1. Main app redirects to `/oauth/authorize` with client_id, redirect_uri, state
2. User signs in via ASWebAuthenticationSession
3. Callback to `minutalarm://callback?code=...`
4. Exchange code for tokens via POST to `/oauth/token` with grant_type=authorization_code
5. Store `MinutCredentials` in keychain

### API Endpoints Used
- `GET /homes` - List user's homes (main app only)
- `GET /homes/{id}/alarm` - Get alarm status (returns `{alarm: {enabled: bool, mode?: string}}`)
- `PATCH /homes/{id}/alarm` - Set alarm status (send `{alarm: {enabled: bool}}`)
- `POST /oauth/token` - Token exchange and refresh

### Request Format
All API requests require:
- Header: `Authorization: Bearer {access_token}`
- Header: `Accept: application/json` or `Content-Type: application/json`

## Common Development Pitfalls

### Widget Shows "Sign In Required"
- Credentials are in keychain but App Group ID mismatch prevents access
- Check that `SharedSettings.suiteName` matches both entitlements files
- Verify App Group is enabled for both targets in Signing & Capabilities

### Widget Not Updating After Code Changes
- Widget extensions are cached aggressively by iOS
- Delete the widget from home screen and re-add it
- Or restart the device/simulator

### OAuth Credentials Mismatch
If widget fails to refresh tokens but main app works:
- Credentials in `WidgetAPIService.swift` don't match `MinutAlarmWidgetApp.swift`
- Widget cannot fall back to main app's credentials due to process isolation

### Widget Timeline Not Refreshing
Widget uses `Timeline.ReloadPolicy.after(nextUpdate)` set to 15 minutes, but iOS may delay updates:
- Background budget is limited by iOS
- Use `WidgetCenter.shared.reloadTimelines(ofKind:)` after critical changes
- Main app calls this after home selection changes

## File Organization

### Shared/ Directory
Code that MUST be compiled into both targets:
- `SharedModels.swift` - All Codable types (MinutHome, MinutCredentials, API responses)
- `SharedSettings.swift` - App Group UserDefaults wrapper
- `KeychainHelper.swift` - Keychain access with App Group support

When adding new shared code, add the file to BOTH targets in Xcode's Target Membership panel.

### Widget Extension Constraints
The widget extension cannot:
- Present UI (no `UIViewController`, no alerts)
- Perform OAuth flows
- Access URLSchemes directly for deep linking
- Run indefinitely (has strict CPU/memory limits)

The widget CAN:
- Use `AppIntents` for button interactions (iOS 17+)
- Refresh tokens via background network requests
- Read/write keychain and App Group storage
- Schedule timeline updates
