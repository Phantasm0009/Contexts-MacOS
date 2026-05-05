import AppKit

/// Bridges AppKit lifecycle events into the SwiftUI app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Placeholder for future first-launch setup, permissions, etc.
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NotificationCenter.default.post(name: .contextsRecheckAccessibility, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NotificationCenter.default.post(name: .contextsRecheckAccessibility, object: nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar utility: keep running when the dashboard window closes.
        false
    }
}
