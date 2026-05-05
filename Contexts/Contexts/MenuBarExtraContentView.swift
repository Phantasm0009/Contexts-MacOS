import AppKit
import SwiftData
import SwiftUI

/// Status bar popover content: quick actions and dashboard launcher.
struct MenuBarExtraContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var licenseManager: LicenseManager

    @Query private var workContexts: [WorkContext]

    private var orderedContexts: [WorkContext] {
        workContexts.sorted {
            let a = $0.orderIndex ?? Int.max
            let b = $1.orderIndex ?? Int.max
            if a != b { return a < b }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
    private var pinnedContexts: [WorkContext] { orderedContexts.filter(\.isPinned) }
    private var unpinnedContexts: [WorkContext] { orderedContexts.filter { !$0.isPinned } }
    private var orderedContextsForShortcuts: [WorkContext] { pinnedContexts + unpinnedContexts }

    /// Maps the first 9 contexts to Option+1...Option+9 keyboard shortcuts.
    private var shortcutSlotByPersistentID: [PersistentIdentifier: Int] {
        var map: [PersistentIdentifier: Int] = [:]
        for (idx, context) in orderedContextsForShortcuts.prefix(9).enumerated() {
            map[context.persistentModelID] = idx + 1
        }
        return map
    }

    private var activeContextHeadline: String {
        guard let active = sessionManager.activeContext else {
            return "Active Context: None"
        }
        return "Active Context: \(active.name)"
    }

    private var activeContextHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: sessionManager.activeContext?.icon ?? "square.stack.3d.up")
                .font(.title3)
                .frame(width: 28, height: 28)
                .foregroundStyle(.white)
                .background(Color.accentColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(activeContextHeadline)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if sessionManager.sessionStartTime != nil {
                    TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                        if let start = sessionManager.sessionStartTime {
                            Text(Self.formattedSessionElapsed(since: start, now: timeline.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.13))
        )
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
                MenuRowButton(title: "Clear Active Context", systemImage: "xmark.circle", shortcutHint: nil) {
                    sessionManager.clearActiveSession()
                }
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
                    Text("No contexts yet. Open Dashboard to create one.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Pinned")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                    ForEach(pinnedContexts, id: \.persistentModelID) { context in
                        contextRunButton(context, shortcutSlot: shortcutSlotByPersistentID[context.persistentModelID])
                    }

                    Divider()
                        .padding(.vertical, 2)

                    Text("Other Contexts")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                    ForEach(unpinnedContexts, id: \.persistentModelID) { context in
                        contextRunButton(context, shortcutSlot: shortcutSlotByPersistentID[context.persistentModelID])
                    }
                }
            }

            Divider()

            MenuRowButton(title: "Open Dashboard", systemImage: "rectangle.on.rectangle", shortcutHint: nil) {
                openWindow(id: ContextsApp.dashboardWindowID)
            }

            MenuRowButton(title: "License...", systemImage: "key.fill", shortcutHint: nil) {
                openWindow(id: ContextsApp.licenseWindowID)
            }

            Divider()

            MenuRowButton(title: "Quit", systemImage: "power", shortcutHint: nil) {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(minWidth: 260)
        .background(.ultraThinMaterial)
        .onAppear {
            sessionManager.restorePersistedActiveContext(modelContext: modelContext)
        }
    }

    private func contextRunButton(_ context: WorkContext, shortcutSlot: Int?) -> some View {
        MenuRowButton(
            title: context.name,
            systemImage: context.icon,
            shortcutHint: shortcutSlot.map { "⌥\($0)" }
        ) {
            Task {
                await sessionManager.run(context: context)
            }
        }
        .modifier(OptionNumberShortcutModifier(slot: shortcutSlot))
    }

    private var isTrialExpired: Bool {
        if case .expired = licenseManager.status { return true }
        return false
    }
}

private struct MenuRowButton: View {
    let title: String
    let systemImage: String
    let shortcutHint: String?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                Spacer(minLength: 6)
                if let shortcutHint {
                    Text(shortcutHint)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct OptionNumberShortcutModifier: ViewModifier {
    let slot: Int?

    func body(content: Content) -> some View {
        switch slot {
        case 1:
            content.keyboardShortcut("1", modifiers: [.option])
        case 2:
            content.keyboardShortcut("2", modifiers: [.option])
        case 3:
            content.keyboardShortcut("3", modifiers: [.option])
        case 4:
            content.keyboardShortcut("4", modifiers: [.option])
        case 5:
            content.keyboardShortcut("5", modifiers: [.option])
        case 6:
            content.keyboardShortcut("6", modifiers: [.option])
        case 7:
            content.keyboardShortcut("7", modifiers: [.option])
        case 8:
            content.keyboardShortcut("8", modifiers: [.option])
        case 9:
            content.keyboardShortcut("9", modifiers: [.option])
        default:
            content
        }
    }
}
