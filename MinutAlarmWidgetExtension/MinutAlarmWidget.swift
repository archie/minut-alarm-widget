// MinutAlarmWidget.swift
// iOS Widget for controlling Minut alarm

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct AlarmEntry: TimelineEntry {
    let date: Date
    let isArmed: Bool
    let homeId: String
    let state: WidgetState
    
    enum WidgetState {
        case ready
        case loading
        case notAuthenticated
        case noHomeSelected
        case error(String)
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
        Task {
            let entry = await fetchCurrentEntry()
            
            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchCurrentEntry() async -> AlarmEntry {
        let homeId = SharedSettings.homeId
        guard !homeId.isEmpty else {
            return AlarmEntry(
                date: Date(),
                isArmed: false,
                homeId: "",
                state: .noHomeSelected
            )
        }

        do {
            let token = try await WidgetAPIService.shared.getValidAccessToken()
            let alarmInfo = try await WidgetAPIService.shared.getAlarmStatus(
                homeId: homeId,
                accessToken: token
            )

            // Cache the state
            SharedSettings.lastKnownAlarmState = alarmInfo.isArmed
            SharedSettings.lastUpdateTime = Date()

            return AlarmEntry(
                date: Date(),
                isArmed: alarmInfo.isArmed,
                homeId: homeId,
                state: .ready
            )

        } catch {
            if case MinutAuthError.missingCredentials = error {
                return AlarmEntry(
                    date: Date(),
                    isArmed: false,
                    homeId: homeId,
                    state: .notAuthenticated
                )
            }

            // Return cached state on error
            return AlarmEntry(
                date: Date(),
                isArmed: SharedSettings.lastKnownAlarmState,
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
        let homeId = SharedSettings.homeId
        guard !homeId.isEmpty else {
            throw MinutAPIError.notFound
        }
        
        let token = try await WidgetAPIService.shared.getValidAccessToken()
        
        try await WidgetAPIService.shared.setAlarmStatus(
            homeId: homeId,
            enabled: enable,
            accessToken: token
        )
        
        // Update cached state
        SharedSettings.lastKnownAlarmState = enable
        SharedSettings.lastUpdateTime = Date()
        
        // Reload widget
        WidgetCenter.shared.reloadTimelines(ofKind: "MinutAlarmWidget")
        
        return .result()
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
        VStack(spacing: 12) {
            statusIndicator
            toggleButton
            
            if family != .systemSmall {
                Text("Updated \(entry.date, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    @ViewBuilder
    private var readyViewWithError: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            statusIndicator
            toggleButton
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isArmed ? "lock.shield.fill" : "lock.shield")
                .font(.title2)
                .foregroundColor(entry.isArmed ? .green : .secondary)
            
            Text(entry.isArmed ? "Armed" : "Disarmed")
                .font(.headline)
                .foregroundColor(entry.isArmed ? .green : .secondary)
        }
    }
    
    @ViewBuilder
    private var toggleButton: some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleAlarmIntent(enable: !entry.isArmed)) {
                HStack {
                    Image(systemName: entry.isArmed ? "lock.open.fill" : "lock.fill")
                    Text(entry.isArmed ? "Disarm" : "Arm")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(entry.isArmed ? Color.orange : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: URL(string: "minutalarm://toggle?action=\(entry.isArmed ? "disarm" : "arm")")!) {
                HStack {
                    Image(systemName: entry.isArmed ? "lock.open.fill" : "lock.fill")
                    Text(entry.isArmed ? "Disarm" : "Arm")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(entry.isArmed ? Color.orange : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
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
