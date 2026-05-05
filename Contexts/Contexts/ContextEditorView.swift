import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Full editor for a single `WorkContext`; `@Bindable` keeps SwiftData fields in sync with SwiftUI controls.
struct ContextEditorView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var context: WorkContext

    @State private var newURLString = ""

    private let suggestedIcons = [
        "square.stack.3d.up.fill",
        "chevron.left.forwardslash.chevron.right",
        "doc.text.fill",
        "hammer.fill",
        "bubble.left.and.bubble.right.fill",
        "person.crop.circle",
        "desktopcomputer",
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

            Section("Focus shortcut") {
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
                Text(
                    "When this context runs, Contexts executes `/usr/bin/shortcuts run \"…\"`. "
                        + "Create a shortcut in the Shortcuts app (e.g. “Coding Focus”) and enter its exact name."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section("Applications") {
                if context.appResources.isEmpty {
                    Text("No applications yet").foregroundStyle(.secondary)
                } else {
                    ForEach(context.appResources) { resource in
                        AppResourceEditorRow(resource: resource)
                    }
                    .onDelete(perform: deleteAppResources)
                }
                Button("Choose Application...") {
                    chooseApplicationFromApplicationsFolder()
                }
                .help("Choose an app from /Applications — its bundle identifier is added to this context.")
            }

            Section("URLs") {
                if context.webResources.isEmpty {
                    Text("No URLs yet").foregroundStyle(.secondary)
                } else {
                    ForEach(context.webResources) { resource in
                        WebResourceEditorRow(resource: resource)
                    }
                    .onDelete(perform: deleteWebResources)
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
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snap.bundleID).font(.body.monospaced())
                                Text(
                                    String(
                                        format: "frame: (%.0f, %.0f)  %.0f×%.0f",
                                        snap.x,
                                        snap.y,
                                        snap.width,
                                        snap.height
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

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
        let engine = WorkspaceEngine()
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
        let resource = AppResource(bundleID: id, workContext: context)
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
        for index in offsets.sorted(by: >) {
            guard context.appResources.indices.contains(index) else { continue }
            modelContext.delete(context.appResources[index])
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
        let resource = WebResource(urlString: normalized, workContext: context)
        modelContext.insert(resource)
        newURLString = ""
    }

    private func deleteWebResources(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard context.webResources.indices.contains(index) else { continue }
            modelContext.delete(context.webResources[index])
        }
    }
}

private struct AppResourceEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var resource: AppResource

    @State private var isEditingBundleID = false

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

private struct WebResourceEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var resource: WebResource

    var body: some View {
        HStack(spacing: 8) {
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
