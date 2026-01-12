// MinutAlarmWidget.swift
// iOS Widget for controlling Minut alarm

import WidgetKit
import SwiftUI
import AppIntents
import os.log

private let logger = Logger(subsystem: "se.akacian.minut-alarm-widget", category: "Widget")

// MARK: - Timeline Entry

struct AlarmEntry: TimelineEntry {
    let date: Date
    let isArmed: Bool
    let isInGracePeriod: Bool
    let gracePeriodExpiresAt: Date?
    let homeId: String
    let state: WidgetState

    enum WidgetState {
        case ready
        case loading
        case notAuthenticated
        case noHomeSelected
        case error(String)
    }

    init(date: Date, isArmed: Bool, isInGracePeriod: Bool = false, gracePeriodExpiresAt: Date? = nil, homeId: String, state: WidgetState) {
        self.date = date
        self.isArmed = isArmed
        self.isInGracePeriod = isInGracePeriod
        self.gracePeriodExpiresAt = gracePeriodExpiresAt
        self.homeId = homeId
        self.state = state
    }
}

// MARK: - Timeline Provider

struct AlarmWidgetProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> AlarmEntry {
        AlarmEntry(
            date: Date(),
            isArmed: false,
            homeId: "",
            state: .loading
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (AlarmEntry) -> Void) {
        if context.isPreview {
            completion(AlarmEntry(
                date: Date(),
                isArmed: true,
                homeId: "preview",
                state: .ready
            ))
            return
        }
        
        Task {
            let entry = await fetchCurrentEntry()
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmEntry>) -> Void) {
        logger.info("⏰ Widget: getTimeline called")
        Task {
            let entry = await fetchCurrentEntry()

            // If in grace period, refresh when it expires (plus a small buffer)
            let nextUpdate: Date
            if entry.isInGracePeriod, let expiresAt = entry.gracePeriodExpiresAt {
                nextUpdate = expiresAt.addingTimeInterval(3) // Refresh 3 seconds after grace period ends
                logger.info("⏱️ Widget: In grace period, scheduling update at \(nextUpdate)")
            } else {
                // Normal refresh every 15 minutes
                nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
                logger.info("📅 Widget: Scheduling next update at \(nextUpdate)")
            }

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchCurrentEntry() async -> AlarmEntry {
        logger.info("🔄 Widget: Starting fetchCurrentEntry")

        let homeId = SharedSettings.homeId
        guard !homeId.isEmpty else {
            logger.warning("⚠️ Widget: No home selected, showing noHomeSelected state")
            return AlarmEntry(
                date: Date(),
                isArmed: false,
                homeId: "",
                state: .noHomeSelected
            )
        }

        logger.info("📍 Widget: Using home ID: \(homeId)")

        do {
            logger.info("🔐 Widget: Getting valid access token...")
            let token = try await WidgetAPIService.shared.getValidAccessToken()
            logger.info("✅ Widget: Successfully got access token")

            logger.info("📡 Widget: Fetching alarm status from API...")
            let alarmInfo = try await WidgetAPIService.shared.getAlarmStatus(
                homeId: homeId,
                accessToken: token
            )

            let isInGracePeriod = alarmInfo.isInArmingGracePeriod
            logger.info("✅ Widget: Successfully fetched alarm status - isArmed: \(alarmInfo.isArmed), status: \(alarmInfo.alarmStatus.rawValue), detailed: \(alarmInfo.detailedAlarmStatus ?? "nil"), inGracePeriod: \(isInGracePeriod)")

            if isInGracePeriod, let expiresAt = alarmInfo.gracePeriodExpiresAt {
                logger.info("⏱️ Widget: Grace period expires at \(expiresAt)")
            }

            // Cache the state
            SharedSettings.lastKnownAlarmState = alarmInfo.isArmed
            SharedSettings.lastUpdateTime = Date()
            logger.info("💾 Widget: Cached alarm state: \(alarmInfo.isArmed)")

            return AlarmEntry(
                date: Date(),
                isArmed: alarmInfo.isArmed,
                isInGracePeriod: isInGracePeriod,
                gracePeriodExpiresAt: alarmInfo.gracePeriodExpiresAt,
                homeId: homeId,
                state: .ready
            )

        } catch {
            logger.error("❌ Widget: Error occurred - \(error.localizedDescription)")

            if case MinutAuthError.missingCredentials = error {
                logger.warning("🔒 Widget: Missing credentials, showing notAuthenticated state")
                return AlarmEntry(
                    date: Date(),
                    isArmed: false,
                    homeId: homeId,
                    state: .notAuthenticated
                )
            }

            if let authError = error as? MinutAuthError {
                logger.error("🔐 Widget: Auth error type: \(String(describing: authError))")
            } else if let apiError = error as? MinutAPIError {
                logger.error("📡 Widget: API error type: \(String(describing: apiError))")
            } else {
                logger.error("❓ Widget: Unknown error type: \(String(describing: type(of: error)))")
            }

            // Return cached state on error
            let cachedState = SharedSettings.lastKnownAlarmState
            let lastUpdate = SharedSettings.lastUpdateTime
            logger.warning("🗂️ Widget: Using cached state - isArmed: \(cachedState), last updated: \(lastUpdate?.description ?? "never")")

            return AlarmEntry(
                date: Date(),
                isArmed: cachedState,
                homeId: homeId,
                state: .error(error.localizedDescription)
            )
        }
    }
}

// MARK: - Toggle Intent (iOS 17+)

@available(iOS 17.0, *)
struct ToggleAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Alarm"
    static var description = IntentDescription("Arms or disarms the Minut alarm")
    
    @Parameter(title: "Enable Alarm")
    var enable: Bool
    
    init() {
        self.enable = false
    }
    
    init(enable: Bool) {
        self.enable = enable
    }
    
    func perform() async throws -> some IntentResult {
        logger.info("🎯 Widget Intent: Setting alarm to \(self.enable ? "ON" : "OFF")")

        let homeId = SharedSettings.homeId
        guard !homeId.isEmpty else {
            logger.error("❌ Widget Intent: No home selected")
            throw MinutAPIError.notFound
        }

        logger.info("📍 Widget Intent: Using home ID: \(homeId)")

        do {
            logger.info("🔐 Widget Intent: Getting access token...")
            let token = try await WidgetAPIService.shared.getValidAccessToken()

            logger.info("📡 Widget Intent: Setting alarm status to \(self.enable ? "ON" : "OFF")...")
            try await WidgetAPIService.shared.setAlarmStatus(
                homeId: homeId,
                enabled: self.enable,
                accessToken: token
            )

            logger.info("✅ Widget Intent: Successfully set alarm status")

            // Fetch the actual state from API to ensure accuracy
            logger.info("📡 Widget Intent: Fetching actual alarm state after update...")
            let alarmInfo = try await WidgetAPIService.shared.getAlarmStatus(
                homeId: homeId,
                accessToken: token
            )

            // Update cached state with actual API response
            SharedSettings.lastKnownAlarmState = alarmInfo.isArmed
            SharedSettings.lastUpdateTime = Date()
            logger.info("💾 Widget Intent: Updated cached state to \(alarmInfo.isArmed) (status: \(alarmInfo.alarmStatus.rawValue), detailed: \(alarmInfo.detailedAlarmStatus ?? "nil"), inGracePeriod: \(alarmInfo.isInArmingGracePeriod))")

            // Reload widget
            WidgetCenter.shared.reloadTimelines(ofKind: "MinutAlarmWidget")
            logger.info("🔄 Widget Intent: Triggered widget reload")

            return .result()
        } catch {
            logger.error("❌ Widget Intent: Failed to toggle alarm - \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Widget Views

struct AlarmWidgetView: View {
    let entry: AlarmEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch entry.state {
        case .ready:
            readyView
        case .loading:
            loadingView
        case .notAuthenticated:
            notAuthenticatedView
        case .noHomeSelected:
            noHomeSelectedView
        case .error:
            // Show last known state with error indicator
            readyViewWithError
        }
    }
    
    // MARK: - Ready State

    @ViewBuilder
    private var readyView: some View {
        VStack(spacing: 8) {
            toggleButton

            Text("\(entry.date, style: .relative) ago")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var readyViewWithError: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            toggleButton
            
            Text("\(entry.date, style: .relative) ago")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var toggleButton: some View {
        if #available(iOS 17.0, *) {
            // In grace period: always send "off" to cancel, otherwise toggle
            let enableAlarm = entry.isInGracePeriod ? false : !entry.isArmed

            Button(intent: ToggleAlarmIntent(enable: enableAlarm)) {
                buttonContent
            }
            .buttonStyle(.plain)
        } else {
            let action = entry.isInGracePeriod ? "disarm" : (entry.isArmed ? "disarm" : "arm")
            Link(destination: URL(string: "minutalarm://toggle?action=\(action)")!) {
                buttonContent
            }
        }
    }

    @ViewBuilder
    private var buttonContent: some View {
        if entry.isInGracePeriod, let expiresAt = entry.gracePeriodExpiresAt {
            // Grace period countdown view
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "timer")
                    Text("Arming in")
                }
                .font(.caption)

                Text(expiresAt, style: .timer)
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)

                Text("Tap to cancel")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .background(Color.minutAction)
            .foregroundColor(.minutContrast)
            .cornerRadius(10)
        } else {
            // Normal armed/disarmed view
            HStack {
                Image(systemName: entry.isArmed ? "lock.shield.fill" : "lock.shield")
                Text(entry.isArmed ? "Alarm on" : "Alarm off")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(entry.isArmed ? Color.minutContrast : Color.minutClarity)
            .foregroundColor(entry.isArmed ? .white : .minutContrast)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    // MARK: - Not Authenticated State
    
    private var notAuthenticatedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Sign In Required")
                .font(.headline)
            
            Text("Open app to sign in")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    // MARK: - No Home Selected State
    
    private var noHomeSelectedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "house.circle")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text("Select a Home")
                .font(.headline)
            
            Text("Open app to configure")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Definition

struct MinutAlarmWidget: Widget {
    let kind: String = "MinutAlarmWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlarmWidgetProvider()) { entry in
            AlarmWidgetView(entry: entry)
        }
        .configurationDisplayName("Minut Alarm")
        .description("Control your home alarm")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Armed", as: .systemSmall) {
    MinutAlarmWidget()
} timeline: {
    AlarmEntry(date: Date(), isArmed: true, homeId: "home1", state: .ready)
}

#Preview("Disarmed", as: .systemMedium) {
    MinutAlarmWidget()
} timeline: {
    AlarmEntry(date: Date(), isArmed: false, homeId: "home1", state: .ready)
}

#Preview("Grace Period", as: .systemMedium) {
    MinutAlarmWidget()
} timeline: {
    AlarmEntry(
        date: Date(),
        isArmed: true,
        isInGracePeriod: true,
        gracePeriodExpiresAt: Date().addingTimeInterval(45),
        homeId: "home1",
        state: .ready
    )
}
