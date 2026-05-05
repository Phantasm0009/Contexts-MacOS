import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Full editor for a single `WorkContext`; `@Bindable` keeps SwiftData fields in sync with SwiftUI controls.
struct ContextEditorView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var context: WorkContext

    @State private var newURLString = ""
    @State private var isVerifyingShortcut = false
    @State private var shortcutVerificationMessage: String?
    @State private var shortcutVerificationIsError = false

    private let suggestedIcons = [
        "square.stack.3d.up.fill",
        "chevron.left.forwardslash.chevron.right",
        "paintpalette.fill",
        "film.stack.fill",
        "music.note.list",
        "waveform.path.ecg.rectangle.fill",
        "newspaper.fill",
        "book.fill",
        "doc.richtext.fill",
        "calendar",
        "clock.fill",
        "checklist.checked",
        "list.bullet.rectangle.portrait.fill",
        "folder.fill",
        "folder.badge.gearshape",
        "archivebox.fill",
        "tray.full.fill",
        "doc.text.fill",
        "doc.text.magnifyingglass",
        "doc.badge.gearshape",
        "globe",
        "network",
        "wifi",
        "terminal",
        "hammer.fill",
        "wrench.and.screwdriver.fill",
        "gearshape.2.fill",
        "chart.bar.fill",
        "chart.line.uptrend.xyaxis",
        "person.2.fill",
        "person.3.fill",
        "bubble.left.and.bubble.right.fill",
        "envelope.fill",
        "phone.fill",
        "video.fill",
        "video.bubble.left.fill",
        "camera.fill",
        "mic.fill",
        "headphones",
        "gamecontroller.fill",
        "shippingbox.fill",
        "briefcase.fill",
        "building.2.fill",
        "graduationcap.fill",
        "lightbulb.fill",
        "sparkles",
        "person.crop.circle",
        "desktopcomputer",
        "laptopcomputer",
        "display.2",
        "ipad",
        "applewatch",
        "safari",
        "terminal.fill",
    ]

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $context.name)
                Toggle("Pinned", isOn: $context.isPinned)
                LabeledContent("Icon") {
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedIcons, id: \.self) { symbol in
                                    Button {
                                        context.icon = symbol
                                    } label: {
                                        Image(systemName: symbol)
                                            .font(.title2)
                                            .frame(width: 36, height: 36)
                                            .background(context.icon == symbol ? Color.accentColor.opacity(0.2) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                    .help(symbol)
                                }
                            }
                        }
                        TextField("SF Symbol name", text: $context.icon)
                            .font(.body.monospaced())
                    }
                }
            }

            Section("Notes") {
                TextEditor(
                    text: Binding(
                        get: { context.notes ?? "" },
                        set: {
                            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                            context.notes = trimmed.isEmpty ? nil : $0
                        }
                    )
                )
                .frame(minHeight: 90)
                .font(.body)
                .overlay(
                    Group {
                        if (context.notes ?? "").isEmpty {
                            Text("What is this context for?")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 6)
                                .padding(.top, 8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                    }
                )
            }

            Section("Focus shortcut") {
                HStack(spacing: 8) {
                    TextField(
                    "Shortcuts name (optional)",
                    text: Binding(
                        get: { context.focusShortcutName ?? "" },
                        set: {
                            let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                            context.focusShortcutName = t.isEmpty ? nil : t
                        }
                    )
                    )
                    .textContentType(.none)

                    Button {
                        Task { await verifyFocusShortcut() }
                    } label: {
                        if isVerifyingShortcut {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Verify")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isVerifyingShortcut || (context.focusShortcutName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let shortcutVerificationMessage {
                    Text(shortcutVerificationMessage)
                        .font(.caption)
                        .foregroundStyle(shortcutVerificationIsError ? .red : .green)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(
                    "When this context runs, Contexts executes `/usr/bin/shortcuts run \"…\"`. "
                        + "Create a shortcut in the Shortcuts app (e.g. “Coding Focus”) and enter its exact name."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section("Applications") {
                if appResourcesSorted.isEmpty {
                    Text("No applications yet").foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(Array(appResourcesSorted.enumerated()), id: \.element.persistentModelID) { index, resource in
                            AppResourceEditorRow(
                                resource: resource,
                                reorderIndex: index,
                                reorderCount: appResourcesSorted.count,
                                onMoveUp: { swapAdjacentAppResources(movingItemAt: index, direction: -1) },
                                onMoveDown: { swapAdjacentAppResources(movingItemAt: index, direction: 1) }
                            )
                        }
                        .onMove(perform: moveAppResources)
                        .onDelete(perform: deleteAppResources)
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 48)
                    .frame(
                        maxHeight: CGFloat(
                            min(
                                max(appResourcesSorted.count, 1) * 56 + 12,
                                420
                            )
                        )
                    )
                    Text("Drag rows or use the arrows to set launch order.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Choose Application...") {
                    chooseApplicationFromApplicationsFolder()
                }
                .help("Choose an app from /Applications — its bundle identifier is added to this context.")
            }

            Section("URLs") {
                if webResourcesSorted.isEmpty {
                    Text("No URLs yet").foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(Array(webResourcesSorted.enumerated()), id: \.element.persistentModelID) { index, resource in
                            WebResourceEditorRow(
                                resource: resource,
                                reorderIndex: index,
                                reorderCount: webResourcesSorted.count,
                                onMoveUp: { swapAdjacentWebResources(movingItemAt: index, direction: -1) },
                                onMoveDown: { swapAdjacentWebResources(movingItemAt: index, direction: 1) }
                            )
                        }
                        .onMove(perform: moveWebResources)
                        .onDelete(perform: deleteWebResources)
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 40)
                    .frame(
                        maxHeight: CGFloat(
                            min(
                                max(webResourcesSorted.count, 1) * 44 + 12,
                                420
                            )
                        )
                    )
                    Text("Drag rows or use the arrows to set open order.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    TextField("https://…", text: $newURLString)
                        .textContentType(.URL)
                    Button("Add") {
                        addWebResource()
                    }
                    .disabled(newURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Window layout") {
                Button("Capture Current Windows to This Context") {
                    captureCurrentWorkspace()
                }
                if windowSnapshotsSorted.isEmpty {
                    Text("No snapshots — capture your visible windows or run Restore after capturing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(windowSnapshotsSorted, id: \.persistentModelID) { snap in
                        HStack(spacing: 8) {
                            SnapshotEditorRow(snapshot: snap)

                            Button(role: .destructive) {
                                modelContext.delete(snap)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete Snapshot")
                        }
                        .contextMenu {
                            Button("Delete Snapshot", role: .destructive) {
                                modelContext.delete(snap)
                            }
                        }
                    }
                    .onDelete(perform: deleteWindowSnapshots)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle(context.name)
    }

    /// Stable order so list indices match `.onDelete` offsets.
    private var windowSnapshotsSorted: [WindowSnapshot] {
        context.windowSnapshots.sorted {
            let ar = $0.stackOrder ?? Int.max
            let br = $1.stackOrder ?? Int.max
            if ar != br { return ar < br }
            return $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending
        }
    }

    private func captureCurrentWorkspace() {
        let engine = WorkspaceEngine.shared
        let captured = engine.captureVisibleWindows()
        let existing = Array(context.windowSnapshots)
        for snap in existing {
            modelContext.delete(snap)
        }
        context.windowSnapshots.removeAll()
        for cap in captured {
            let inserted = WindowSnapshot(
                bundleID: cap.bundleID,
                x: cap.x,
                y: cap.y,
                width: cap.width,
                height: cap.height,
                stackOrder: cap.stackOrder,
                workContext: context
            )
            modelContext.insert(inserted)
        }
    }

    private func chooseApplicationFromApplicationsFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.message = "Select an application to use its bundle identifier for this context."
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            if panel.runModal() == .OK {
                applyPickedApplicationURL(panel.url)
            }
            return
        }

        panel.beginSheetModal(for: window) { response in
            Task { @MainActor in
                if response == .OK {
                    self.applyPickedApplicationURL(panel.url)
                }
            }
        }
    }

    /// Called from application picker completions (must stay on MainActor).
    private func applyPickedApplicationURL(_ url: URL?) {
        guard let url,
              let id = Bundle(url: url)?.bundleIdentifier,
              !id.isEmpty
        else { return }
        insertAppResourceIfNew(bundleID: id)
    }

    /// Inserts an `AppResource` when that bundle ID is not already in this context.
    private func insertAppResourceIfNew(bundleID id: String) {
        guard !context.appResources.contains(where: { $0.bundleID == id }) else { return }
        let resource = AppResource(bundleID: id, sortOrder: nextAppSortOrder, workContext: context)
        modelContext.insert(resource)
    }

    private func deleteWindowSnapshots(at offsets: IndexSet) {
        let snaps = windowSnapshotsSorted
        for index in offsets.sorted(by: >) {
            guard snaps.indices.contains(index) else { continue }
            modelContext.delete(snaps[index])
        }
    }

    private func deleteAppResources(at offsets: IndexSet) {
        let resources = appResourcesSorted
        for index in offsets.sorted(by: >) {
            guard resources.indices.contains(index) else { continue }
            modelContext.delete(resources[index])
        }
    }

    private func addWebResource() {
        let trimmed = newURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lower = trimmed.lowercased()
        let normalized: String
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            normalized = trimmed
        } else {
            normalized = "https://" + trimmed
        }
        let resource = WebResource(urlString: normalized, sortOrder: nextWebSortOrder, workContext: context)
        modelContext.insert(resource)
        newURLString = ""
    }

    private func deleteWebResources(at offsets: IndexSet) {
        let resources = webResourcesSorted
        for index in offsets.sorted(by: >) {
            guard resources.indices.contains(index) else { continue }
            modelContext.delete(resources[index])
        }
    }

    private func moveAppResources(from source: IndexSet, to destination: Int) {
        var items = appResourcesSorted
        items.move(fromOffsets: source, toOffset: destination)
        renumberAppResourceSortOrders(items)
    }

    private func moveWebResources(from source: IndexSet, to destination: Int) {
        var items = webResourcesSorted
        items.move(fromOffsets: source, toOffset: destination)
        renumberWebResourceSortOrders(items)
    }

    private func swapAdjacentAppResources(movingItemAt index: Int, direction: Int) {
        var items = appResourcesSorted
        guard direction == -1 || direction == 1 else { return }
        let pairStart: Int
        if direction < 0 {
            guard index > 0 else { return }
            pairStart = index - 1
        } else {
            guard index < items.count - 1 else { return }
            pairStart = index
        }
        items.swapAt(pairStart, pairStart + 1)
        renumberAppResourceSortOrders(items)
    }

    private func swapAdjacentWebResources(movingItemAt index: Int, direction: Int) {
        var items = webResourcesSorted
        guard direction == -1 || direction == 1 else { return }
        let pairStart: Int
        if direction < 0 {
            guard index > 0 else { return }
            pairStart = index - 1
        } else {
            guard index < items.count - 1 else { return }
            pairStart = index
        }
        items.swapAt(pairStart, pairStart + 1)
        renumberWebResourceSortOrders(items)
    }

    private func renumberAppResourceSortOrders(_ items: [AppResource]) {
        for (idx, resource) in items.enumerated() {
            resource.sortOrder = idx
        }
    }

    private func renumberWebResourceSortOrders(_ items: [WebResource]) {
        for (idx, resource) in items.enumerated() {
            resource.sortOrder = idx
        }
    }

    private var appResourcesSorted: [AppResource] {
        context.appResources.sorted {
            let a = $0.sortOrder ?? Int.max
            let b = $1.sortOrder ?? Int.max
            if a != b { return a < b }
            return $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending
        }
    }

    private var webResourcesSorted: [WebResource] {
        context.webResources.sorted {
            let a = $0.sortOrder ?? Int.max
            let b = $1.sortOrder ?? Int.max
            if a != b { return a < b }
            return $0.urlString.localizedStandardCompare($1.urlString) == .orderedAscending
        }
    }

    private var nextAppSortOrder: Int {
        (context.appResources.compactMap(\.sortOrder).max() ?? -1) + 1
    }

    private var nextWebSortOrder: Int {
        (context.webResources.compactMap(\.sortOrder).max() ?? -1) + 1
    }

    private func verifyFocusShortcut() async {
        let name = (context.focusShortcutName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isVerifyingShortcut = true
        shortcutVerificationMessage = nil
        defer { isVerifyingShortcut = false }

        do {
            let output = try await listInstalledShortcuts()
            let exists = output
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })

            shortcutVerificationIsError = !exists
            shortcutVerificationMessage = exists
                ? "Shortcut found."
                : "Shortcut not found in `shortcuts list`."
        } catch {
            shortcutVerificationIsError = true
            shortcutVerificationMessage = "Unable to verify shortcut: \(error.localizedDescription)"
        }
    }

    private func listInstalledShortcuts() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self)
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: NSError(domain: "Contexts.Shortcuts", code: Int(proc.terminationStatus), userInfo: nil))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private struct AppResourceEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var resource: AppResource

    @State private var isEditingBundleID = false

    private let reorderIndex: Int?
    private let reorderCount: Int?
    private let onMoveUp: (() -> Void)?
    private let onMoveDown: (() -> Void)?

    init(
        resource: AppResource,
        reorderIndex: Int? = nil,
        reorderCount: Int? = nil,
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil
    ) {
        self._resource = Bindable(wrappedValue: resource)
        self.reorderIndex = reorderIndex
        self.reorderCount = reorderCount
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
    }

    private var trimmedBundleID: String {
        resource.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolved `.app` URL for the current bundle identifier, if installed.
    private var applicationURL: URL? {
        guard !trimmedBundleID.isEmpty else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmedBundleID)
    }

    /// Localized display name when the app exists; otherwise the raw bundle ID (or placeholder when empty).
    private var resolvedDisplayName: String {
        guard !trimmedBundleID.isEmpty else {
            return "Unknown bundle identifier"
        }
        guard let url = applicationURL else {
            return trimmedBundleID
        }
        let bundle = Bundle(url: url)
        let candidates: [String?] = [
            bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.localizedInfoDictionary?["CFBundleName"] as? String,
            bundle?.infoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.infoDictionary?["CFBundleName"] as? String,
        ]
        if let name = candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) {
            return name
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    private var resolvedIcon: NSImage? {
        guard let url = applicationURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                if let idx = reorderIndex,
                   let count = reorderCount,
                   let onMoveUp,
                   let onMoveDown
                {
                    VStack(spacing: 2) {
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .disabled(idx == 0)
                        .help("Move up")

                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .disabled(idx >= count - 1)
                        .help("Move down")
                    }
                    .frame(width: 18)
                }

                Group {
                    if let icon = resolvedIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"))
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                }

                Text(resolvedDisplayName)
                    .font(.body)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer(minLength: 8)

                Button(isEditingBundleID ? "Done" : "Edit") {
                    isEditingBundleID.toggle()
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize()

                Button(role: .destructive) {
                    deleteResource()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete Application")
            }

            if isEditingBundleID {
                TextField("Bundle ID", text: $resource.bundleID)
                    .font(.body.monospaced())
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Delete Application", role: .destructive) {
                deleteResource()
            }
        }
    }

    private func deleteResource() {
        modelContext.delete(resource)
    }
}

private struct SnapshotEditorRow: View {
    let snapshot: WindowSnapshot

    @State private var isHovering = false

    private var bundleID: String { snapshot.bundleID.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var applicationURL: URL? {
        guard !bundleID.isEmpty else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    private var icon: NSImage {
        if let url = applicationURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns")
    }

    private var appDisplayName: String {
        guard let url = applicationURL else { return bundleID }
        let bundle = Bundle(url: url)
        let candidates: [String?] = [
            bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.localizedInfoDictionary?["CFBundleName"] as? String,
            bundle?.infoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.infoDictionary?["CFBundleName"] as? String,
        ]
        if let name = candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) {
            return name
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(appDisplayName)
                    .font(.body)
                if isHovering {
                    Text(
                        String(
                            format: "frame: (%.0f, %.0f)  %.0f×%.0f",
                            snapshot.x,
                            snapshot.y,
                            snapshot.width,
                            snapshot.height
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

private struct WebResourceEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var resource: WebResource

    private let reorderIndex: Int?
    private let reorderCount: Int?
    private let onMoveUp: (() -> Void)?
    private let onMoveDown: (() -> Void)?

    init(
        resource: WebResource,
        reorderIndex: Int? = nil,
        reorderCount: Int? = nil,
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil
    ) {
        self._resource = Bindable(wrappedValue: resource)
        self.reorderIndex = reorderIndex
        self.reorderCount = reorderCount
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
    }

    var body: some View {
        HStack(spacing: 8) {
            if let idx = reorderIndex,
               let count = reorderCount,
               let onMoveUp,
               let onMoveDown
            {
                VStack(spacing: 2) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(idx == 0)
                    .help("Move up")

                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(idx >= count - 1)
                    .help("Move down")
                }
                .frame(width: 18)
            }

            TextField("URL", text: $resource.urlString)
                .textContentType(.URL)
                .textSelection(.enabled)
            Button(role: .destructive) {
                deleteResource()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete URL")
        }
        .contextMenu {
            Button("Delete URL", role: .destructive) {
                deleteResource()
            }
        }
    }

    private func deleteResource() {
        modelContext.delete(resource)
    }
}
