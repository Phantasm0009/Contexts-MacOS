import AppKit
import ApplicationServices
import CoreFoundation
import CoreGraphics
import Foundation

enum WorkspaceEngineError: LocalizedError {
    case appNotFound(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound(let id):
            return "No application installed for bundle identifier “\(id)”."
        }
    }
}

/// Captures window geometry via Quartz Window Services and (when trusted) refines frames with Accessibility (`AXUIElement`).
final class WorkspaceEngine {
    static let shared = WorkspaceEngine()

    private init() {}

    private nonisolated(unsafe) static let axFrameAttribute = "AXFrame" as CFString
    private nonisolated(unsafe) static let axPositionAttribute = "AXPosition" as CFString
    private nonisolated(unsafe) static let axSizeAttribute = "AXSize" as CFString
    private nonisolated(unsafe) static let axRaiseAction = "AXRaise" as CFString

    /// Processes like the Accessibility consent banner — not real workspace windows.
    private static let excludedWorkspaceBundleIDs: Set<String> = [
        "com.apple.accessibility.universalAccessAuthWarn",
        "com.apple.SecurityAgent",
    ]

    /// Enumerates on-screen windows and returns detached `WindowSnapshot` rows (not inserted into SwiftData).
    /// - Parameter excludingContextsApp: Skips windows owned by this app so captures aren’t polluted during testing.
    func captureVisibleWindows(excludingContextsApp: Bool = true) -> [WindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let ownBundle = Bundle.main.bundleIdentifier
        var results: [WindowSnapshot] = []
        results.reserveCapacity(rawList.count)
        // Quartz returns windows front-to-back; we preserve that order for restore-time z-order.
        var frontToBackStackIndex = 0

        for window in rawList {
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            if layer != 0 {
                continue
            }

            guard let pid = pid(from: window) else { continue }

            if excludingContextsApp,
               let ownBundle,
               let app = NSRunningApplication(processIdentifier: pid),
               app.bundleIdentifier == ownBundle {
                continue
            }

            guard let bundleID = bundleID(for: pid) else { continue }

            if Self.excludedWorkspaceBundleIDs.contains(bundleID) {
                continue
            }

            let title = window[kCGWindowName as String] as? String
            let cgBounds = cgBoundsQuartz(from: window)

            let frameAppKit: CGRect
            if AXIsProcessTrusted(), let ax = axFrame(for: pid, windowTitle: title, approximateQuartzBounds: cgBounds) {
                frameAppKit = ax
            } else if let cgBounds {
                frameAppKit = Self.quartzGlobalBoundsToAppKit(cgBounds)
            } else {
                continue
            }

            results.append(
                WindowSnapshot(
                    bundleID: bundleID,
                    x: Double(frameAppKit.origin.x),
                    y: Double(frameAppKit.origin.y),
                    width: Double(frameAppKit.width),
                    height: Double(frameAppKit.height),
                    stackOrder: frontToBackStackIndex
                )
            )
            frontToBackStackIndex += 1
        }

        return results
    }

    /// Moves/resizes windows using Accessibility (`AXPosition` / `AXSize`), then restores **stacking order**.
    ///
    /// Uses persisted `stackOrder` to restore stacking deterministically.
    ///
    /// - `stackOrder` captures the global z-order sequence at capture time.
    /// - We still match geometry using the `snapshots` loop below, but we then compute an explicit raise order
    ///   from `stackOrder` so the correct window ends up on top.
    func restoreWindows(from snapshots: [WindowSnapshot]) {
        guard AXIsProcessTrusted() else {
            print("[Contexts] Restore Setup skipped: Accessibility is not trusted for this process.")
            return
        }
        guard !snapshots.isEmpty else {
            print("[Contexts] Restore Setup: no snapshots.")
            return
        }

        // Higher ranks are raised earlier (behind), lower ranks are raised later (on top).
        // `nil`/legacy snapshots are treated as lowest confidence and raised first.
        func stackRank(_ s: WindowSnapshot) -> Int { s.stackOrder ?? Int.max }

        // Deterministic processing order for geometry matching (doesn't control z-order).
        let snapshots = snapshots.sorted {
            let ar = stackRank($0)
            let br = stackRank($1)
            if ar != br { return ar < br }
            if $0.bundleID != $1.bundleID {
                return $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending
            }
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.width + $0.height < $1.width + $1.height
        }

        var pools: [String: [AXUIElement]] = [:]
        var bundlesNeeded = Set<String>()
        for s in snapshots {
            bundlesNeeded.insert(s.bundleID)
        }

        for bundleID in bundlesNeeded {
            guard let pid = pidForBundleMatchingVisibleWindows(bundleID: bundleID) else {
                print("[Contexts] Restore Setup: \(bundleID) is not running — skipped pool.")
                continue
            }
            guard let raw = Self.gatherAXWindowElements(pid: pid, bundleID: bundleID) else {
                continue
            }
            let axWindows = raw.filter { Self.axRoleIsMainWindowLike($0) }
            if axWindows.isEmpty {
                print("[Contexts] Restore Setup: no AX windows for \(bundleID).")
            } else {
                pools[bundleID] = axWindows
            }
        }

        var placed: [(rank: Int, bundleID: String, element: AXUIElement)] = []
        placed.reserveCapacity(snapshots.count)

        for snapshot in snapshots {
            guard var pool = pools[snapshot.bundleID], !pool.isEmpty else {
                print("[Contexts] Restore Setup: no pool match for \(snapshot.bundleID) — skipped one target.")
                continue
            }

            let goal = CGPoint(
                x: CGFloat(snapshot.x + snapshot.width / 2),
                y: CGFloat(snapshot.y + snapshot.height / 2)
            )

            guard
                let bestIndex = pool.indices.min(by: { a, b in
                    let fa = Self.axFrame(of: pool[a])
                    let fb = Self.axFrame(of: pool[b])
                    let da: CGFloat
                    let db: CGFloat
                    if let fa {
                        da = hypot(fa.midX - goal.x, fa.midY - goal.y)
                    } else {
                        da = .greatestFiniteMagnitude
                    }
                    if let fb {
                        db = hypot(fb.midX - goal.x, fb.midY - goal.y)
                    } else {
                        db = .greatestFiniteMagnitude
                    }
                    return da < db
                })
            else {
                continue
            }

            let element = pool.remove(at: bestIndex)
            pools[snapshot.bundleID] = pool

            let rect = CGRect(
                x: CGFloat(snapshot.x),
                y: CGFloat(snapshot.y),
                width: CGFloat(snapshot.width),
                height: CGFloat(snapshot.height)
            )
            Self.applyPositionAndSize(rect, to: element, bundleID: snapshot.bundleID)
            placed.append((rank: stackRank(snapshot), bundleID: snapshot.bundleID, element: element))
        }

        guard !placed.isEmpty else {
            print("[Contexts] Restore Setup finished (no windows matched).")
            return
        }

        // Raise order: back-most first, front-most last so the desired front window ends up on top.
        // With our `stackRank` fallback (`nil` -> Int.max), unknown/legacy snapshots are raised early (behind others).
        let raiseOrder = placed.sorted { a, b in
            if a.rank != b.rank { return a.rank > b.rank } // higher rank first
            return a.bundleID.localizedStandardCompare(b.bundleID) == .orderedAscending
        }

        var lastActivatedBundleID: String?
        for item in raiseOrder {
            if lastActivatedBundleID != item.bundleID {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID)
                    .first(where: { !$0.isTerminated }) {
                    app.activate()
                }
                lastActivatedBundleID = item.bundleID
            }
            let err = AXUIElementPerformAction(item.element, Self.axRaiseAction)
            if err != .success {
                print("[Contexts] Restore Setup: AXRaise failed — AXError \(err.rawValue)")
            }
        }

        print("[Contexts] Restore Setup finished.")
    }

    /// Launches an installed application by bundle identifier.
    func launchApplication(
        bundleID: String,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            completion(.failure(WorkspaceEngineError.appNotFound(bundleID)))
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Polls until each distinct bundle ID has at least one running, finished-launching process, or `timeoutSeconds` elapses (then returns anyway).
    func waitForAppsToLaunch(bundleIDs: [String], timeoutSeconds: Double = 15.0) async {
        let uniqueIDs = Array(Set(bundleIDs)).filter { !$0.isEmpty }
        guard !uniqueIDs.isEmpty else { return }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let allReady = await MainActor.run {
                Self.allRequestedAppsFinishedLaunching(bundleIDs: uniqueIDs)
            }
            if allReady { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    /// Opens a URL in the user’s default browser (or appropriate handler).
    @discardableResult
    func open(url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    /// Hides visible distraction apps so only the current context’s bundles (plus Finder & Contexts) stay foreground-eligible.
    ///
    /// Skips apps whose bundle ID is in `bundleIDsToKeep`, **Finder**, **Contexts**, anything without a bundle ID,
    /// and processes whose activation policy is not `.regular` (agents, backgrounds).
    func hideUnassociatedApps(keeping bundleIDsToKeep: [String]) {
        let keep = Set(bundleIDsToKeep)
        let ownBundleID = Bundle.main.bundleIdentifier

        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier else { continue }
            if keep.contains(bundleID) { continue }
            if bundleID == Self.finderBundleID { continue }
            if let ownBundleID, bundleID == ownBundleID { continue }
            guard app.activationPolicy == .regular else { continue }
            app.hide()
        }
    }

    private static let finderBundleID = "com.apple.finder"

    /// Runs `/usr/bin/shortcuts run "<name>"` when `shortcutName` is non-empty (e.g. a shortcut that toggles Focus).
    /// Executes off the main actor so workspace orchestration stays responsive; failures log to the console.
    func runInstalledShortcutIfConfigured(named shortcutName: String) {
        let trimmed = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", trimmed]
            let drain = Pipe()
            process.standardOutput = drain
            process.standardError = drain

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    print("[Contexts] shortcuts run \"\(trimmed)\" exited with status \(process.terminationStatus)")
                }
            } catch {
                print("[Contexts] shortcuts run \"\(trimmed)\" failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    @MainActor
    private static func allRequestedAppsFinishedLaunching(bundleIDs: [String]) -> Bool {
        for bundleID in bundleIDs {
            let hasReadyInstance = NSWorkspace.shared.runningApplications.contains { app in
                guard let id = app.bundleIdentifier, id == bundleID else { return false }
                return !app.isTerminated && app.isFinishedLaunching
            }
            if !hasReadyInstance { return false }
        }
        return true
    }

    /// Prefer the **PID that actually owns on-screen windows** (same source as capture). `runningApplications(withBundleIdentifier:)`
    /// can return a helper process for Safari/Notes so `AXUIElementCreateApplication` had no `AXWindows`.
    private func pidForBundleMatchingVisibleWindows(bundleID: String) -> pid_t? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return fallbackPID(for: bundleID)
        }

        var candidateCounts: [pid_t: Int] = [:]
        for window in rawList {
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            guard layer == 0, let pid = pid(from: window) else { continue }
            guard self.bundleID(for: pid) == bundleID else { continue }
            candidateCounts[pid, default: 0] += 1
        }

        if let best = candidateCounts.max(by: { $0.value < $1.value })?.key {
            return best
        }
        return fallbackPID(for: bundleID)
    }

    private func fallbackPID(for bundleID: String) -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { !$0.isTerminated })?
            .processIdentifier
    }

    /// `-25204` is `kAXErrorCannotComplete` — common until the target app is activated and its AX tree is ready.
    /// Strategy: activate → retry `AXWindows` → recurse `AXChildren` for `AXWindow` roles.
    private static func gatherAXWindowElements(pid: pid_t, bundleID: String) -> [AXUIElement]? {
        let maxAttempts = 4
        for attempt in 1 ... maxAttempts {
            NSRunningApplication(processIdentifier: pid)?.activate()

            let delayMicroseconds: useconds_t = attempt == 1 ? 50_000 : 120_000
            usleep(delayMicroseconds)

            let appElement = AXUIElementCreateApplication(pid)

            var ref: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &ref)
            if err == .success, let windows = materializeAXElementArray(ref), !windows.isEmpty {
                if attempt > 1 {
                    print("[Contexts] Restore Setup: AXWindows succeeded for \(bundleID) on attempt \(attempt).")
                }
                return windows
            }

            if err != .success {
                print(
                    "[Contexts] Restore Setup: AXWindows attempt \(attempt)/\(maxAttempts) for \(bundleID) — AXError \(err.rawValue)"
                )
            }
        }

        print("[Contexts] Restore Setup: using AX children fallback for \(bundleID) (AXWindows unavailable).")
        let appElement = AXUIElementCreateApplication(pid)
        var fallback: [AXUIElement] = []
        collectAXWindowsRecursively(from: appElement, depth: 0, maxDepth: 28, into: &fallback)
        if fallback.isEmpty {
            print("[Contexts] Restore Setup: children fallback found no AXWindow for \(bundleID).")
            return nil
        }
        return fallback
    }

    /// Unwraps `CFArray` of `AXUIElementRef` when Swift bridging to `[AXUIElement]` fails.
    private static func materializeAXElementArray(_ ref: CFTypeRef?) -> [AXUIElement]? {
        guard let value = ref else { return nil }
        if let bridged = value as? [AXUIElement] { return bridged }
        guard CFGetTypeID(value) == CFArrayGetTypeID() else { return nil }

        let cfArray = value as! CFArray
        let count = CFArrayGetCount(cfArray)
        var elements: [AXUIElement] = []
        elements.reserveCapacity(count)
        for i in 0 ..< count {
            let rawPtr = CFArrayGetValueAtIndex(cfArray, i)
            elements.append(Unmanaged<AXUIElement>.fromOpaque(rawPtr!).takeUnretainedValue())
        }
        return elements
    }

    private static func collectAXWindowsRecursively(
        from element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        into result: inout [AXUIElement]
    ) {
        guard depth <= maxDepth else { return }

        var roleRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        if let role = roleRef as? String, role == "AXWindow" {
            result.append(element)
            return
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = materializeAXElementArray(childrenRef)
        else {
            return
        }

        for child in children {
            collectAXWindowsRecursively(from: child, depth: depth + 1, maxDepth: maxDepth, into: &result)
        }
    }

    private static func axRoleIsMainWindowLike(_ element: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String
        if role == nil || role == "AXWindow" {
            return true
        }
        return false
    }

    /// Reads `AXFrame` for an AX window element.
    private static func axFrame(of element: AXUIElement) -> CGRect? {
        var frameRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, axFrameAttribute, &frameRef) == .success,
              let axValue = frameRef,
              CFGetTypeID(axValue as CFTypeRef) == AXValueGetTypeID()
        else {
            return nil
        }
        let value = axValue as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(value, .cgRect, &rect) else { return nil }
        return rect
    }

    private static func applyPositionAndSize(_ rect: CGRect, to window: AXUIElement, bundleID: String) {
        var origin = rect.origin
        var size = rect.size

        guard let axPosition = AXValueCreate(AXValueType.cgPoint, &origin) else {
            print("[Contexts] Restore Setup: AXValueCreate(position) failed — \(bundleID)")
            return
        }
        var err = AXUIElementSetAttributeValue(window, axPositionAttribute, axPosition)
        if err != .success {
            print("[Contexts] Restore Setup: set position failed for \(bundleID) — AXError \(err.rawValue)")
        }

        guard let axSize = AXValueCreate(AXValueType.cgSize, &size) else {
            print("[Contexts] Restore Setup: AXValueCreate(size) failed — \(bundleID)")
            return
        }
        err = AXUIElementSetAttributeValue(window, axSizeAttribute, axSize)
        if err != .success {
            print("[Contexts] Restore Setup: set size failed for \(bundleID) — AXError \(err.rawValue)")
        }
    }

    private func pid(from window: [String: Any]) -> pid_t? {
        if let n = window[kCGWindowOwnerPID as String] as? NSNumber {
            return pid_t(truncating: n)
        }
        if let i = window[kCGWindowOwnerPID as String] as? Int32 {
            return pid_t(i)
        }
        return nil
    }

    private func bundleID(for pid: pid_t) -> String? {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    private func cgBoundsQuartz(from window: [String: Any]) -> CGRect? {
        guard let dict = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dict as CFDictionary)
    }

    /// Quartz window bounds use a bottom-left origin on the global desktop; convert to AppKit-style rects (top-left origin, Y growing downward) in the **same global coordinate space** `NSWindow` frames use.
    private static func quartzGlobalBoundsToAppKit(_ quartzRect: CGRect) -> CGRect {
        guard !NSScreen.screens.isEmpty else { return quartzRect }

        var union = CGRect.null
        for s in NSScreen.screens {
            union = union.union(s.frame)
        }
        let globalMaxY = union.maxY
        let y = globalMaxY - quartzRect.origin.y - quartzRect.height
        return CGRect(x: quartzRect.origin.x, y: y, width: quartzRect.width, height: quartzRect.height)
    }

    /// When Accessibility is trusted, match an AX window by title (and rough overlap with Quartz bounds) and read `kAXFrame`.
    private func axFrame(for pid: pid_t, windowTitle: String?, approximateQuartzBounds: CGRect?) -> CGRect? {
        let appEl = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement]
        else {
            return nil
        }

        let normalizedTitle = windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var candidates: [(score: CGFloat, rect: CGRect)] = []

        for winEl in axWindows {
            var roleRef: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(winEl, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String
            if let role, role != "AXWindow" {
                continue
            }

            var titleRef: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(winEl, kAXTitleAttribute as CFString, &titleRef)
            let axTitle = (titleRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            var frameRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(winEl, Self.axFrameAttribute, &frameRef) == .success,
                  let axValue = frameRef,
                  CFGetTypeID(axValue as CFTypeRef) == AXValueGetTypeID()
            else {
                continue
            }

            let value = axValue as! AXValue
            var rect = CGRect.zero
            guard AXValueGetValue(value, .cgRect, &rect) else { continue }

            var score: CGFloat = 0
            if let normalizedTitle, !normalizedTitle.isEmpty, let axTitle, axTitle == normalizedTitle {
                score += 100
            }
            if let approx = approximateQuartzBounds {
                let convertedApprox = Self.quartzGlobalBoundsToAppKit(approx)
                let dx = rect.midX - convertedApprox.midX
                let dy = rect.midY - convertedApprox.midY
                score += max(0, 50 - hypot(dx, dy) / 10)
            } else {
                score += 1
            }

            candidates.append((score, rect))
        }

        return candidates.max(by: { $0.score < $1.score })?.rect
    }
}
