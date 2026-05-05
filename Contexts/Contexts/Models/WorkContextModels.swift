import Foundation
import SwiftData

/// Root persisted object: a saved “work mode” with apps, URLs, and optional window geometry.
@Model
final class WorkContext {
    var id: UUID
    var name: String
    /// SF Symbol name (e.g. `chevron.left.forwardslash.chevron.right`).
    var icon: String
    /// Optional user-authored note describing what this context is for.
    var notes: String?
    /// User-controlled ordering in lists/menu (lower appears first). `nil` means legacy rows with unspecified order.
    var orderIndex: Int?
    /// Last time this context was successfully run from app UI or App Intent.
    var lastRunAt: Date?
    var isPinned: Bool
    /// Optional Shortcuts app shortcut name (`shortcuts run "<name>"`) for Focus-style automation when this context runs.
    /// Stored as optional so lightweight migration can add the column without failing on existing rows (nil = unset).
    var focusShortcutName: String?

    @Relationship(deleteRule: .cascade, inverse: \AppResource.workContext)
    var appResources: [AppResource]

    @Relationship(deleteRule: .cascade, inverse: \WebResource.workContext)
    var webResources: [WebResource]

    @Relationship(deleteRule: .cascade, inverse: \WindowSnapshot.workContext)
    var windowSnapshots: [WindowSnapshot]

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        notes: String? = nil,
        orderIndex: Int? = nil,
        lastRunAt: Date? = nil,
        isPinned: Bool = false,
        focusShortcutName: String? = nil,
        appResources: [AppResource] = [],
        webResources: [WebResource] = [],
        windowSnapshots: [WindowSnapshot] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.notes = notes
        self.orderIndex = orderIndex
        self.lastRunAt = lastRunAt
        self.isPinned = isPinned
        self.focusShortcutName = focusShortcutName
        self.appResources = appResources
        self.webResources = webResources
        self.windowSnapshots = windowSnapshots
    }
}

/// An application to launch when the context runs, keyed by bundle identifier.
@Model
final class AppResource {
    var bundleID: String
    /// Persisted stable ordering in a context's app list.
    var sortOrder: Int?

    var workContext: WorkContext?

    init(bundleID: String, sortOrder: Int? = nil, workContext: WorkContext? = nil) {
        self.bundleID = bundleID
        self.sortOrder = sortOrder
        self.workContext = workContext
    }
}

/// A URL to open when the context runs.
@Model
final class WebResource {
    var urlString: String
    /// Persisted stable ordering in a context's URL list.
    var sortOrder: Int?

    var workContext: WorkContext?

    init(urlString: String, sortOrder: Int? = nil, workContext: WorkContext? = nil) {
        self.urlString = urlString
        self.sortOrder = sortOrder
        self.workContext = workContext
    }
}

/// Best-effort window frame snapshot for restore (origin and size in screen points).
@Model
final class WindowSnapshot {
    var bundleID: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    /// Global front-to-back order at capture time: **lower = more front-most** (`0` = topmost captured window).
    /// Matches the order emitted by `CGWindowListCopyWindowInfo` after filtering (`WorkspaceEngine.captureVisibleWindows`).
    /// `nil` = legacy snapshots captured before stacking was persisted (stable but not guaranteed z-order).
    var stackOrder: Int?

    var workContext: WorkContext?

    init(
        bundleID: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        stackOrder: Int? = nil,
        workContext: WorkContext? = nil
    ) {
        self.bundleID = bundleID
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.stackOrder = stackOrder
        self.workContext = workContext
    }
}

/// Historical run/session entry for a context.
@Model
final class ContextSessionLog {
    var contextID: UUID
    var contextName: String
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: TimeInterval?

    init(
        contextID: UUID,
        contextName: String,
        startedAt: Date,
        endedAt: Date? = nil,
        durationSeconds: TimeInterval? = nil
    ) {
        self.contextID = contextID
        self.contextName = contextName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
    }
}
