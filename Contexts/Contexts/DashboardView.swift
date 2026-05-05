import AppKit
import os
import SwiftData
import SwiftUI

/// Main dashboard: browse persisted contexts and smoke-test SwiftData.
struct DashboardView: View {
    private static let logger = Logger(subsystem: "com.contexts.Contexts", category: "DashboardView")

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var permissionsManager: PermissionsManager
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var licenseManager: LicenseManager
    @Query private var workContexts: [WorkContext]
    @Query(sort: \ContextSessionLog.startedAt, order: .reverse) private var sessionLogs: [ContextSessionLog]

    @State private var selectedContextPersistentID: PersistentIdentifier?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedContextPersistentID) {
                if !permissionsManager.isAccessibilityTrusted {
                    Section("Setup Health") {
                        SetupHealthView()
                    }
                }

                Section("Contexts") {
                    if filteredContexts.isEmpty {
                        ContentUnavailableView(
                            "No contexts yet",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("Create one to save your work setup.")
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredContexts) { context in
                            contextListRow(context)
                                .tag(context.persistentModelID)
                                .contextMenu {
                                    Button("Duplicate") {
                                        duplicateContext(context)
                                    }
                                    Button("Delete", role: .destructive) {
                                        deleteContext(context)
                                    }
                                }
                        }
                        .onDelete(perform: deleteContexts)
                        .onMove(perform: moveContexts)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search contexts")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            Group {
                if let selectedContextPersistentID,
                   let selected = workContexts.first(where: { $0.persistentModelID == selectedContextPersistentID }) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            ContextEditorView(context: selected)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Run History")
                                    .font(.headline)
                                if recentSessions(for: selected).isEmpty {
                                    Text("No sessions yet.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(recentSessions(for: selected)) { log in
                                        HStack {
                                            Text(relativeTime(from: log.startedAt))
                                            Spacer()
                                            if let duration = log.durationSeconds {
                                                Text(formattedDuration(duration))
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                Text("Active")
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .font(.caption)
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Contexts",
                        systemImage: "square.stack.3d.up.fill",
                        description: Text("Select a context in the sidebar or create a new one.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Dashboard")
        .safeAreaInset(edge: .top) {
            if isTrialExpired {
                Button {
                    openWindow(id: ContextsApp.licenseWindowID)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                        Text("Your free trial has expired. Click here to activate.")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                permissionsManager.refreshAccessibilityStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            permissionsManager.refreshAccessibilityStatus()
        }
        .onAppear {
            normalizeOrderIndexesIfNeeded()
            sessionManager.restorePersistedActiveContext(modelContext: modelContext)
            if selectedContextPersistentID == nil {
                selectedContextPersistentID = orderedContexts.first?.persistentModelID
            }
        }
        .onChange(of: workContexts.count) { _, _ in
            guard let sel = selectedContextPersistentID else {
                selectedContextPersistentID = orderedContexts.first?.persistentModelID
                return
            }
            if !workContexts.contains(where: { $0.persistentModelID == sel }) {
                selectedContextPersistentID = orderedContexts.first?.persistentModelID
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("New Context") {
                    insertNewContext()
                }
                Button("Capture Current Setup") {
                    captureToolbarSnapshotsToSelectedContext()
                }
                .disabled(selectedContextPersistentID == nil)
                .help(captureToolbarHelpText)
            }
        }
    }

    private var captureToolbarHelpText: String {
        if selectedContext == nil {
            return "Select a context in the sidebar before capturing setup."
        }
        return "Replaces the selected context’s saved window snapshots with the current screen layout."
    }

    private var restoreSetupHelpText: String {
        if isTrialExpired {
            return "Trial expired. Open License to activate Contexts Pro."
        }
        if selectedContext == nil {
            return "Select a context in the sidebar before restoring setup."
        }
        if !canRestoreSelectedContext {
            return "Capture setup for the selected context first."
        }
        if !permissionsManager.isAccessibilityTrusted {
            return "Enable Accessibility for Contexts in System Settings → Privacy & Security → Accessibility."
        }
        return "Apply the last captured window frames via Accessibility APIs."
    }

    /// Toolbar capture: persists directly into the currently selected `WorkContext`.
    private func captureToolbarSnapshotsToSelectedContext() {
        guard let ctx = selectedContext else { return }

        let engine = WorkspaceEngine.shared
        let captured = engine.captureVisibleWindows()
        replaceWindowSnapshots(of: ctx, withCaptured: captured)
        Self.logger.info("Capture Current Setup saved \(captured.count) window(s) into context \(ctx.name, privacy: .public)")
        for snap in captured {
            Self.logger.info(
                "snapshot bundle=\(snap.bundleID, privacy: .public) x=\(snap.x) y=\(snap.y) width=\(snap.width) height=\(snap.height)"
            )
        }
    }

    private func restoreSetupFromSelectedContext() {
        guard let ctx = selectedContext else { return }
        let snapshots = ctx.windowSnapshots.map {
            WindowSnapshot(
                bundleID: $0.bundleID,
                x: $0.x,
                y: $0.y,
                width: $0.width,
                height: $0.height,
                stackOrder: $0.stackOrder
            )
        }
        let engine = WorkspaceEngine.shared
        engine.restoreWindows(from: snapshots)
    }

    private func replaceWindowSnapshots(of ctx: WorkContext, withCaptured captured: [WindowSnapshot]) {
        let existing = Array(ctx.windowSnapshots)
        for snap in existing {
            modelContext.delete(snap)
        }
        ctx.windowSnapshots.removeAll()
        for cap in captured {
            let inserted = WindowSnapshot(
                bundleID: cap.bundleID,
                x: cap.x,
                y: cap.y,
                width: cap.width,
                height: cap.height,
                stackOrder: cap.stackOrder,
                workContext: ctx
            )
            modelContext.insert(inserted)
        }
    }

    private func deleteContext(_ ctx: WorkContext) {
        let pid = ctx.persistentModelID
        if sessionManager.activeContext?.id == ctx.id {
            sessionManager.clearActiveSession()
        }
        modelContext.delete(ctx)
        if selectedContextPersistentID == pid {
            selectedContextPersistentID = orderedContexts.first(where: { $0.persistentModelID != pid })?.persistentModelID
        }
    }

    private func deleteContexts(at offsets: IndexSet) {
        let contextsToDelete: [WorkContext] = offsets.compactMap { idx in
            filteredContexts.indices.contains(idx) ? filteredContexts[idx] : nil
        }
        let deletingIDs = Set(contextsToDelete.map(\.persistentModelID))

        for ctx in contextsToDelete {
            if sessionManager.activeContext?.id == ctx.id {
                sessionManager.clearActiveSession()
            }
            modelContext.delete(ctx)
        }

        if let sel = selectedContextPersistentID, deletingIDs.contains(sel) {
            let remaining = orderedContexts.filter { ctx in !deletingIDs.contains(ctx.persistentModelID) }
            selectedContextPersistentID = remaining.first?.persistentModelID
        }
    }

    private func insertNewContext() {
        let newContext = WorkContext(
            name: "New Context",
            icon: "square.stack.3d.up",
            orderIndex: nextOrderIndex
        )
        modelContext.insert(newContext)
        selectedContextPersistentID = newContext.persistentModelID
    }

    private func duplicateContext(_ source: WorkContext) {
        let copy = WorkContext(
            name: source.name + " Copy",
            icon: source.icon,
            notes: source.notes,
            orderIndex: nextOrderIndex,
            isPinned: source.isPinned,
            focusShortcutName: source.focusShortcutName
        )
        modelContext.insert(copy)

        for app in source.appResources {
            modelContext.insert(AppResource(bundleID: app.bundleID, sortOrder: app.sortOrder, workContext: copy))
        }
        for web in source.webResources {
            modelContext.insert(WebResource(urlString: web.urlString, sortOrder: web.sortOrder, workContext: copy))
        }
        for snap in source.windowSnapshots {
            modelContext.insert(
                WindowSnapshot(
                    bundleID: snap.bundleID,
                    x: snap.x,
                    y: snap.y,
                    width: snap.width,
                    height: snap.height,
                    stackOrder: snap.stackOrder,
                    workContext: copy
                )
            )
        }
        selectedContextPersistentID = copy.persistentModelID
    }

    private func moveContexts(from source: IndexSet, to destination: Int) {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var updated = orderedContexts
        updated.move(fromOffsets: source, toOffset: destination)
        for (index, context) in updated.enumerated() {
            context.orderIndex = index
        }
    }

    private var isTrialExpired: Bool {
        if case .expired = licenseManager.status { return true }
        return false
    }

    private var selectedContext: WorkContext? {
        guard let selectedContextPersistentID else { return nil }
        return workContexts.first(where: { $0.persistentModelID == selectedContextPersistentID })
    }

    private var canRestoreSelectedContext: Bool {
        guard let selectedContext else { return false }
        return !selectedContext.windowSnapshots.isEmpty
    }

    private var orderedContexts: [WorkContext] {
        workContexts.sorted {
            let a = $0.orderIndex ?? Int.max
            let b = $1.orderIndex ?? Int.max
            if a != b { return a < b }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var filteredContexts: [WorkContext] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return orderedContexts }
        return orderedContexts.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || ($0.notes?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var nextOrderIndex: Int {
        (orderedContexts.compactMap(\.orderIndex).max() ?? -1) + 1
    }

    private func normalizeOrderIndexesIfNeeded() {
        let needsNormalization = workContexts.contains { $0.orderIndex == nil }
        guard needsNormalization else { return }
        let normalized = orderedContexts
        for (idx, ctx) in normalized.enumerated() {
            ctx.orderIndex = idx
        }
    }

    @ViewBuilder
    private func contextListRow(_ context: WorkContext) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(context.name, systemImage: context.icon)
                .symbolRenderingMode(.hierarchical)
            if let last = context.lastRunAt {
                Text("Last used \(relativeTime(from: last))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func recentSessions(for context: WorkContext) -> [ContextSessionLog] {
        sessionLogs.filter { $0.contextID == context.id }.prefix(20).map { $0 }
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

#Preview {
    DashboardView()
        .modelContainer(
            for: [WorkContext.self, AppResource.self, WebResource.self, WindowSnapshot.self, ContextSessionLog.self],
            inMemory: true
        )
        .environmentObject(PermissionsManager())
        .environmentObject(SessionManager())
        .environmentObject(LicenseManager())
        .frame(width: 800, height: 600)
}
