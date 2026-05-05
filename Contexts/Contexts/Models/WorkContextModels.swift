import Foundation
import SwiftData

/// Root persisted object: a saved “work mode” with apps, URLs, and optional window geometry.
@Model
final class WorkContext {
    var id: UUID
    var name: String
    /// SF Symbol name (e.g. `chevron.left.forwardslash.chevron.right`).
    var icon: String
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
        isPinned: Bool = false,
        focusShortcutName: String? = nil,
        appResources: [AppResource] = [],
        webResources: [WebResource] = [],
        windowSnapshots: [WindowSnapshot] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
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

    var workContext: WorkContext?

    init(bundleID: String, workContext: WorkContext? = nil) {
        self.bundleID = bundleID
        self.workContext = workContext
    }
}

/// A URL to open when the context runs.
@Model
final class WebResource {
    var urlString: String

    var workContext: WorkContext?

    init(urlString: String, workContext: WorkContext? = nil) {
        self.urlString = urlString
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
