import Combine
import Foundation
import os
import SwiftData

enum ContextsPreferences {
    /// When enabled, running a context hides regular apps not included in that context.
    /// Off by default to avoid unexpectedly hiding active user work.
    static let hideUnassociatedAppsOnRunKey = "com.contexts.Contexts.hideUnassociatedAppsOnRun"
}

extension Notification.Name {
    /// Posted when persisted session timing (`sessionStartTime`) or related defaults change outside UUID-only updates (e.g. Shortcuts re-run).
    static let contextsPersistedSessionMetadataDidChange = Notification.Name("com.contexts.Contexts.persistedSessionMetadataDidChange")
}

/// Stores `WorkContext.id` so **SessionManager**, Shortcuts (`LaunchSavedContextIntent`), and UI agree after relaunch.
enum ActiveContextUserDefaults {
    static let activeWorkContextUUIDKey = "com.contexts.Contexts.activeWorkContextUUID"
    static let sessionStartTimeKey = "com.contexts.Contexts.sessionStartTime"

    static func saveActiveWorkContext(uuid: UUID) {
        UserDefaults.standard.com_contexts_Contexts_activeWorkContextUUID = uuid.uuidString as NSString
    }

    static func clearActiveWorkContext() {
        UserDefaults.standard.com_contexts_Contexts_activeWorkContextUUID = nil
        UserDefaults.standard.removeObject(forKey: sessionStartTimeKey)
        NotificationCenter.default.post(name: .contextsPersistedSessionMetadataDidChange, object: nil)
    }

    static func storedActiveWorkContextUUID() -> UUID? {
        guard let string = UserDefaults.standard.com_contexts_Contexts_activeWorkContextUUID as String? else { return nil }
        return UUID(uuidString: string)
    }

    /// Start of the current active context session (wall clock); `nil` when no session.
    static func saveSessionStartTime(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(date, forKey: sessionStartTimeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionStartTimeKey)
        }
        NotificationCenter.default.post(name: .contextsPersistedSessionMetadataDidChange, object: nil)
    }

    static func storedSessionStartTime() -> Date? {
        UserDefaults.standard.object(forKey: sessionStartTimeKey) as? Date
    }
}

extension UserDefaults {
    /// Observable accessor for `ActiveContextUserDefaults.activeWorkContextUUIDKey`.
    /// `@objc dynamic` is required so `UserDefaults.publisher(for:)` emits when this value changes.
    @objc dynamic var com_contexts_Contexts_activeWorkContextUUID: NSString? {
        get { object(forKey: ActiveContextUserDefaults.activeWorkContextUUIDKey) as? NSString }
        set { set(newValue, forKey: ActiveContextUserDefaults.activeWorkContextUUIDKey) }
    }
}

/// Tracks the last context activated from Contexts UI (menu bar today; dashboard later) and orchestrates Workspace runs.
@MainActor
final class SessionManager: ObservableObject {
    private static let logger = Logger(subsystem: "com.contexts.Contexts", category: "SessionManager")

    @Published var activeContext: WorkContext?
    /// Persisted session clock start for `activeContext`; mirrored from `ActiveContextUserDefaults`.
    @Published var sessionStartTime: Date?

    private var cancellables = Set<AnyCancellable>()

    init() {
        UserDefaults.standard
            .publisher(for: \.com_contexts_Contexts_activeWorkContextUUID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshActiveContextFromSharedStore()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .contextsPersistedSessionMetadataDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.reloadSessionTimingFromDefaults()
                }
            }
            .store(in: &cancellables)
    }

    /// Re-resolve `activeContext` from `UserDefaults` using `SharedModelContainer` (same store as App Intents / SwiftUI).
    func refreshActiveContextFromSharedStore() {
        let modelContext = ModelContext(SharedModelContainer.shared)
        applyPersistedActiveContextUUID(modelContext: modelContext)
    }

    /// Reload `activeContext` from UserDefaults using the provided `ModelContext` (e.g. scene `modelContext` on first appear).
    func restorePersistedActiveContext(modelContext: ModelContext) {
        applyPersistedActiveContextUUID(modelContext: modelContext)
    }

    private func applyPersistedActiveContextUUID(modelContext: ModelContext) {
        guard let uuid = ActiveContextUserDefaults.storedActiveWorkContextUUID() else {
            activeContext = nil
            sessionStartTime = nil
            UserDefaults.standard.removeObject(forKey: ActiveContextUserDefaults.sessionStartTimeKey)
            return
        }
        guard let all = try? modelContext.fetch(FetchDescriptor<WorkContext>()),
              let match = all.first(where: { $0.id == uuid }) else {
            ActiveContextUserDefaults.clearActiveWorkContext()
            activeContext = nil
            sessionStartTime = nil
            return
        }
        activeContext = match
        sessionStartTime = ActiveContextUserDefaults.storedSessionStartTime()
    }

    private func reloadSessionTimingFromDefaults() {
        sessionStartTime = ActiveContextUserDefaults.storedSessionStartTime()
    }

    /// Clears the in-memory active session and removes the persisted UUID (menu bar / Shortcuts stay consistent).
    func clearActiveSession() {
        closeCurrentSessionLog(endedAt: Date())
        activeContext = nil
        sessionStartTime = nil
        ActiveContextUserDefaults.clearActiveWorkContext()
    }

    /// Launch apps, open URLs, restore window snapshots, then mark `context` as active.
    func run(context: WorkContext) async {
        let sortedApps = context.appResources.sorted {
            let a = $0.sortOrder ?? Int.max
            let b = $1.sortOrder ?? Int.max
            if a != b { return a < b }
            return $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending
        }
        let sortedWeb = context.webResources.sorted {
            let a = $0.sortOrder ?? Int.max
            let b = $1.sortOrder ?? Int.max
            if a != b { return a < b }
            return $0.urlString.localizedStandardCompare($1.urlString) == .orderedAscending
        }
        let bundleIDs = sortedApps.map(\.bundleID)
        let urls = sortedWeb.compactMap { URL(string: $0.urlString) }
        let snapshotTuples = context.windowSnapshots.map {
            (
                bundleID: $0.bundleID,
                x: $0.x,
                y: $0.y,
                width: $0.width,
                height: $0.height,
                stackOrder: $0.stackOrder
            )
        }

        let engine = WorkspaceEngine.shared

        do {
            for bundleID in bundleIDs {
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

            for url in urls {
                _ = engine.open(url: url)
            }

            let shouldHideUnassociatedApps = UserDefaults.standard.bool(forKey: ContextsPreferences.hideUnassociatedAppsOnRunKey)
            if shouldHideUnassociatedApps {
                engine.hideUnassociatedApps(keeping: bundleIDs)
            }

            await engine.waitForAppsToLaunch(bundleIDs: bundleIDs)

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
            engine.restoreWindows(from: snapshots)

            engine.runInstalledShortcutIfConfigured(named: context.focusShortcutName ?? "")

            let now = Date()
            closeCurrentSessionLog(endedAt: now)
            context.lastRunAt = now
            startSessionLog(for: context, at: now)
            ActiveContextUserDefaults.saveSessionStartTime(now)
            activeContext = context
            ActiveContextUserDefaults.saveActiveWorkContext(uuid: context.id)
            sessionStartTime = now
        } catch {
            Self.logger.error("run(\(context.name, privacy: .public)) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startSessionLog(for context: WorkContext, at start: Date) {
        let modelContext = ModelContext(SharedModelContainer.shared)
        let log = ContextSessionLog(
            contextID: context.id,
            contextName: context.name,
            startedAt: start
        )
        modelContext.insert(log)
    }

    private func closeCurrentSessionLog(endedAt: Date) {
        guard let activeContext, let startedAt = sessionStartTime else { return }
        let modelContext = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<ContextSessionLog>(sortBy: [SortDescriptor(\ContextSessionLog.startedAt, order: .reverse)])
        let open = try? modelContext.fetch(descriptor).first(where: { $0.contextID == activeContext.id && $0.endedAt == nil })

        if let open {
            open.endedAt = endedAt
            open.durationSeconds = max(0, endedAt.timeIntervalSince(open.startedAt))
            return
        }

        // Recovery path for old runs that predate session logging.
        modelContext.insert(
            ContextSessionLog(
                contextID: activeContext.id,
                contextName: activeContext.name,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: max(0, endedAt.timeIntervalSince(startedAt))
            )
        )
    }
}
