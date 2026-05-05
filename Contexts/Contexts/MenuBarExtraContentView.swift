import AppKit
import SwiftData
import SwiftUI

/// Status bar popover content: quick actions and dashboard launcher.
struct MenuBarExtraContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var licenseManager: LicenseManager

    @Query(sort: \WorkContext.name)
    private var workContexts: [WorkContext]

    private var pinnedContexts: [WorkContext] { workContexts.filter(\.isPinned) }
    private var unpinnedContexts: [WorkContext] { workContexts.filter { !$0.isPinned } }

    private var activeContextHeadline: String {
        guard let active = sessionManager.activeContext else {
            return "Active Context: None"
        }
        return "Active Context: \(active.name)"
    }

    private var activeContextHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(activeContextHeadline)
                .font(.headline)
                .foregroundStyle(.secondary)

            if sessionManager.sessionStartTime != nil {
                TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                    if let start = sessionManager.sessionStartTime {
                        Text(Self.formattedSessionElapsed(since: start, now: timeline.date))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    /// Compact elapsed label like `42m` or `1h 12m`.
    private static func formattedSessionElapsed(since start: Date, now: Date) -> String {
        let interval = now.timeIntervalSince(start)
        let totalSeconds = max(0, Int(interval.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            activeContextHeader

            if sessionManager.activeContext != nil {
                Button("Clear Active Context") {
                    sessionManager.clearActiveSession()
                }
                .buttonStyle(.plain)
                .font(.caption)
            }

            Divider()

            if isTrialExpired {
                Button("Trial Expired - Enter License Key") {
                    openWindow(id: ContextsApp.licenseWindowID)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                if pinnedContexts.isEmpty && unpinnedContexts.isEmpty {
                    Text("No saved contexts yet. Open the Dashboard and use “Add ‘Coding’ Sample”.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Pinned")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                    ForEach(pinnedContexts, id: \.persistentModelID) { context in
                        contextRunButton(context)
                    }

                    Divider()
                        .padding(.vertical, 2)

                    Text("Other Contexts")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                    ForEach(unpinnedContexts, id: \.persistentModelID) { context in
                        contextRunButton(context)
                    }
                }
            }

            Divider()

            Button("Open Dashboard") {
                openWindow(id: ContextsApp.dashboardWindowID)
            }

            Button("License...") {
                openWindow(id: ContextsApp.licenseWindowID)
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(minWidth: 260)
        .onAppear {
            sessionManager.restorePersistedActiveContext(modelContext: modelContext)
        }
    }

    private func contextRunButton(_ context: WorkContext) -> some View {
        Button {
            Task {
                await sessionManager.run(context: context)
            }
        } label: {
            Label(context.name, systemImage: context.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var isTrialExpired: Bool {
        if case .expired = licenseManager.status { return true }
        return false
    }
}
