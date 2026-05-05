import AppIntents
import AppKit
import Foundation
import SwiftData

enum RunContextIntentError: LocalizedError {
    case invalidContextID
    case notFound(UUID)

    var errorDescription: String? {
        switch self {
        case .invalidContextID:
            return "That context reference is invalid."
        case .notFound(let id):
            return "No saved context with id \(id.uuidString)."
        }
    }
}

// MARK: - WorkContextEntity (same file ensures type visibility across Xcode indexing / incremental builds)

/// Shortcuts / Spotlight selectable item backed by a persisted `WorkContext` (ID = `WorkContext.id` UUID string).
struct WorkContextEntity: AppEntity {
    typealias ID = String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource(stringLiteral: "Saved Context"))
    }

    static var defaultQuery: WorkContextEntityQuery { WorkContextEntityQuery() }

    var id: String

    /// Display name shown in Shortcuts and suggested entities.
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(workContext: WorkContext) {
        self.id = workContext.id.uuidString
        self.name = workContext.name
    }
}

/// Resolves entities from SwiftData for parameter pickers and phrase matching (“Run Coding in Contexts”).
struct WorkContextEntityQuery: EntityStringQuery {
    func entities(for identifiers: [WorkContextEntity.ID]) async throws -> [WorkContextEntity] {
        try await MainActor.run {
            let uuids = Set(identifiers.compactMap { UUID(uuidString: $0) })
            guard !uuids.isEmpty else { return [] }
            let modelContext = ModelContext(SharedModelContainer.shared)
            let all = try modelContext.fetch(FetchDescriptor<WorkContext>())
            return all.filter { uuids.contains($0.id) }.map { WorkContextEntity(workContext: $0) }
        }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<WorkContextEntity> {
        let list = try await MainActor.run {
            let modelContext = ModelContext(SharedModelContainer.shared)
            let all = try modelContext.fetch(FetchDescriptor<WorkContext>())
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return all.map { WorkContextEntity(workContext: $0) }
            }
            return all.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed)
                    || $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
            }
            .map { WorkContextEntity(workContext: $0) }
        }
        return IntentItemCollection(items: list)
    }

    func suggestedEntities() async throws -> IntentItemCollection<WorkContextEntity> {
        try await entities(matching: "")
    }
}

/// Serializable snapshot of a `WorkContext` for async intent execution without passing SwiftData models across isolation domains.
private struct ContextExecutionPayload: Sendable {
    let displayName: String
    let appBundleIDs: [String]
    let urls: [URL]
    let windowSnapshots: [(bundleID: String, x: Double, y: Double, width: Double, height: Double, stackOrder: Int?)]
    let focusShortcutName: String
}

/// Runs a saved context: launches apps, opens URLs, restores window layout (same engine as Dashboard restore).
///
/// Type name participates in App Intents’ persistent identifier. If Shortcuts shows a stale or wrong label,
/// renaming this struct forces macOS to register a fresh intent (users re-add or recreate shortcuts once).
struct LaunchSavedContextIntent: AppIntent {
    /// Library title in Shortcuts / Spotlight (keep stable for documentation).
    static var title: LocalizedStringResource { "Run Context" }

    /// Summary row when editing the action (explicit avoids generic defaults some OS builds mislabel).
    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$context)")
    }

    static var description: IntentDescription {
        IntentDescription("Launch apps and URLs and restore window layout for a saved Context.")
    }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Saved context")
    var context: WorkContextEntity

    init() {}

    init(context: WorkContextEntity) {
        self.context = context
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let uuid = UUID(uuidString: context.id) else {
            throw RunContextIntentError.invalidContextID
        }

        let payload = try await fetchPayload(workContextID: uuid)

        let engine = WorkspaceEngine()

        for bundleID in payload.appBundleIDs {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                engine.launchApplication(bundleID: bundleID) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            try await Task.sleep(for: .milliseconds(250))
        }

        for url in payload.urls {
            _ = engine.open(url: url)
        }

        engine.hideUnassociatedApps(keeping: payload.appBundleIDs)

        await engine.waitForAppsToLaunch(bundleIDs: payload.appBundleIDs)

        // Build snapshots on the main actor so we never capture non-Sendable `WindowSnapshot` in a `@Sendable` closure.
        let snapshotTuples = payload.windowSnapshots
        await MainActor.run {
            let restoreEngine = WorkspaceEngine()
            let snapshots = snapshotTuples.map {
                WindowSnapshot(
                    bundleID: $0.bundleID,
                    x: $0.x,
                    y: $0.y,
                    width: $0.width,
                    height: $0.height,
                    stackOrder: $0.stackOrder
                )
            }
            restoreEngine.restoreWindows(from: snapshots)
        }

        engine.runInstalledShortcutIfConfigured(named: payload.focusShortcutName)

        ActiveContextUserDefaults.saveSessionStartTime(Date())
        ActiveContextUserDefaults.saveActiveWorkContext(uuid: uuid)

        return .result(dialog: IntentDialog(stringLiteral: "Ran “\(payload.displayName)” in Contexts."))
    }

    private func fetchPayload(workContextID id: UUID) async throws -> ContextExecutionPayload {
        try await MainActor.run {
            let modelContext = ModelContext(SharedModelContainer.shared)
            let descriptor = FetchDescriptor<WorkContext>()
            let all = try modelContext.fetch(descriptor)
            guard let wc = all.first(where: { $0.id == id }) else {
                throw RunContextIntentError.notFound(id)
            }

            let apps = wc.appResources.map(\.bundleID)
            let urls = wc.webResources.compactMap { URL(string: $0.urlString) }

            let snaps = wc.windowSnapshots.map {
                (
                    bundleID: $0.bundleID,
                    x: $0.x,
                    y: $0.y,
                    width: $0.width,
                    height: $0.height,
                    stackOrder: $0.stackOrder
                )
            }

            return ContextExecutionPayload(
                displayName: wc.name,
                appBundleIDs: apps,
                urls: urls,
                windowSnapshots: snaps,
                focusShortcutName: wc.focusShortcutName ?? ""
            )
        }
    }
}
