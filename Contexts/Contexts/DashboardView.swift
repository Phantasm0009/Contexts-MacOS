import AppKit
import SwiftData
import SwiftUI

/// Main dashboard: browse persisted contexts and smoke-test SwiftData.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var permissionsManager: PermissionsManager
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var licenseManager: LicenseManager
    @Query(sort: \WorkContext.name) private var workContexts: [WorkContext]

    @State private var selectedContextPersistentID: PersistentIdentifier?

    /// Last **Capture Current Setup** result (in-memory only), used by **Restore Setup**.
    @State private var lastCapturedSnapshots: [WindowSnapshot] = []

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedContextPersistentID) {
                if !permissionsManager.isAccessibilityTrusted {
                    Section("Setup Health") {
                        SetupHealthView()
                    }
                }

                Section("Contexts") {
                    if workContexts.isEmpty {
                        ContentUnavailableView(
                            "No contexts yet",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("Add the sample “Coding” context to verify persistence.")
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(workContexts) { context in
                            Label(context.name, systemImage: context.icon)
                                .symbolRenderingMode(.hierarchical)
                                .tag(context.persistentModelID)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        deleteContext(context)
                                    }
                                }
                        }
                        .onDelete(perform: deleteContexts)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            Group {
                if let selectedContextPersistentID,
                   let selected = workContexts.first(where: { $0.persistentModelID == selectedContextPersistentID }) {
                    ContextEditorView(context: selected)
                } else {
                    ContentUnavailableView(
                        "Contexts",
                        systemImage: "square.stack.3d.up.fill",
                        description: Text("Select a context in the sidebar or add the sample “Coding” context.")
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
            sessionManager.restorePersistedActiveContext(modelContext: modelContext)
            if selectedContextPersistentID == nil {
                selectedContextPersistentID = workContexts.first?.persistentModelID
            }
        }
        .onChange(of: workContexts.count) { _, _ in
            guard let sel = selectedContextPersistentID else {
                selectedContextPersistentID = workContexts.first?.persistentModelID
                return
            }
            if !workContexts.contains(where: { $0.persistentModelID == sel }) {
                selectedContextPersistentID = workContexts.first?.persistentModelID
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("New Context") {
                    insertNewContext()
                }
                Button("Capture Current Setup") {
                    captureToolbarSnapshotsToSelectionOrScratch()
                }
                .help(captureToolbarHelpText)
                Button("Restore Setup") {
                    let engine = WorkspaceEngine()
                    engine.restoreWindows(from: lastCapturedSnapshots)
                }
                .disabled(lastCapturedSnapshots.isEmpty || !permissionsManager.isAccessibilityTrusted || isTrialExpired)
                .help(restoreSetupHelpText)
                Button("License...") {
                    openWindow(id: ContextsApp.licenseWindowID)
                }
                Button("Add “Coding” Sample") {
                    insertSampleCodingContext()
                }
            }
        }
    }

    private var captureToolbarHelpText: String {
        if selectedContextPersistentID != nil {
            return "Replaces the selected context’s saved window snapshots with the current screen layout."
        }
        return "No sidebar selection — snapshots go to the scratch buffer for Restore Setup below."
    }

    private var restoreSetupHelpText: String {
        if isTrialExpired {
            return "Trial expired. Open License to activate Contexts Pro."
        }
        if lastCapturedSnapshots.isEmpty {
            return "Capture a setup first (scratch buffer only when no context is selected)."
        }
        if !permissionsManager.isAccessibilityTrusted {
            return "Enable Accessibility for Contexts in System Settings → Privacy & Security → Accessibility."
        }
        return "Apply the last captured window frames via Accessibility APIs."
    }

    /// Toolbar capture: persist into the selected `WorkContext`, or keep using `lastCapturedSnapshots` as a scratch buffer.
    private func captureToolbarSnapshotsToSelectionOrScratch() {
        let engine = WorkspaceEngine()
        let captured = engine.captureVisibleWindows()

        if let selectedContextPersistentID,
           let ctx = workContexts.first(where: { $0.persistentModelID == selectedContextPersistentID }) {
            replaceWindowSnapshots(of: ctx, withCaptured: captured)
            print("[Contexts] Capture Current Setup — saved \(captured.count) window(s) into SwiftData context “\(ctx.name)”")
            for snap in captured {
                print(
                    "  bundle=\(snap.bundleID) x=\(snap.x) y=\(snap.y) width=\(snap.width) height=\(snap.height)"
                )
            }
            return
        }

        lastCapturedSnapshots = captured.map {
            WindowSnapshot(
                bundleID: $0.bundleID,
                x: $0.x,
                y: $0.y,
                width: $0.width,
                height: $0.height,
                stackOrder: $0.stackOrder
            )
        }
        print("[Contexts] Capture Current Setup — \(captured.count) window(s) to scratch buffer (select a context in the sidebar to persist)")
        for snap in captured {
            print(
                "  bundle=\(snap.bundleID) x=\(snap.x) y=\(snap.y) width=\(snap.width) height=\(snap.height)"
            )
        }
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
            selectedContextPersistentID = workContexts.first(where: { $0.persistentModelID != pid })?.persistentModelID
        }
    }

    private func deleteContexts(at offsets: IndexSet) {
        let contextsToDelete: [WorkContext] = offsets.compactMap { idx in
            workContexts.indices.contains(idx) ? workContexts[idx] : nil
        }
        let deletingIDs = Set(contextsToDelete.map(\.persistentModelID))

        for ctx in contextsToDelete {
            if sessionManager.activeContext?.id == ctx.id {
                sessionManager.clearActiveSession()
            }
            modelContext.delete(ctx)
        }

        if let sel = selectedContextPersistentID, deletingIDs.contains(sel) {
            let remaining = workContexts.filter { ctx in !deletingIDs.contains(ctx.persistentModelID) }
            selectedContextPersistentID = remaining.first?.persistentModelID
        }
    }

    private func insertSampleCodingContext() {
        let apps = [
            AppResource(bundleID: "com.apple.Terminal"),
            AppResource(bundleID: "com.apple.dt.Xcode"),
        ]
        let webs = [
            WebResource(urlString: "https://developer.apple.com/documentation/"),
        ]
        let windows = [
            WindowSnapshot(
                bundleID: "com.apple.dt.Xcode",
                x: 100,
                y: 120,
                width: 1_200,
                height: 800,
                stackOrder: 0
            ),
        ]

        let coding = WorkContext(
            name: "Coding",
            icon: "chevron.left.forwardslash.chevron.right",
            isPinned: true,
            appResources: apps,
            webResources: webs,
            windowSnapshots: windows
        )

        for app in apps { app.workContext = coding }
        for web in webs { web.workContext = coding }
        for win in windows { win.workContext = coding }

        modelContext.insert(coding)
        selectedContextPersistentID = coding.persistentModelID
    }

    private func insertNewContext() {
        let newContext = WorkContext(
            name: "New Context",
            icon: "square.stack.3d.up"
        )
        modelContext.insert(newContext)
        selectedContextPersistentID = newContext.persistentModelID
    }

    private var isTrialExpired: Bool {
        if case .expired = licenseManager.status { return true }
        return false
    }
}

#Preview {
    DashboardView()
        .modelContainer(
            for: [WorkContext.self, AppResource.self, WebResource.self, WindowSnapshot.self],
            inMemory: true
        )
        .environmentObject(PermissionsManager())
        .environmentObject(SessionManager())
        .environmentObject(LicenseManager())
        .frame(width: 800, height: 600)
}
