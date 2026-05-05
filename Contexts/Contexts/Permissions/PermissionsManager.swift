import AppKit
import ApplicationServices
import Combine
import Foundation

extension Notification.Name {
    /// Posted from `AppDelegate` when the app becomes active so Setup Health re-reads TCC (Accessibility can lag behind UI).
    static let contextsRecheckAccessibility = Notification.Name("com.contexts.recheckAccessibility")
}

/// Central place for macOS permission checks (Accessibility, etc.) used by Setup Health and future flows.
@MainActor
final class PermissionsManager: ObservableObject {
    /// Current Accessibility trust state for this process (`AXIsProcessTrusted()`).
    @Published private(set) var isAccessibilityTrusted: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        refreshAccessibilityStatus()
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .merge(with: NotificationCenter.default.publisher(for: Notification.Name.contextsRecheckAccessibility))
            .sink { [weak self] _ in
                self?.refreshAccessibilityStatus()
            }
            .store(in: &cancellables)
    }

    /// Re-reads Accessibility trust from the system. Call after the user may have changed permissions.
    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    /// Opens **System Settings → Privacy & Security → Accessibility** (or the legacy System Preferences URL, which the OS maps to Settings).
    ///
    /// **Note:** Prefer `x-apple.systempreferences:…` first. The `x-apple.systemsettings:…` form can report
    /// “no application set to open the URL” on some macOS versions even when a second attempt would work.
    func openAccessibilitySettings() {
        let candidates: [String] = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systemsettings:com.apple.preference.security?Privacy_Accessibility",
        ]
        for string in candidates {
            guard let url = URL(string: string) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    /// Asks the system to show the Accessibility trust prompt (may be silent for debug / repeated runs).
    func promptForAccessibilityPermission() {
        let options = NSDictionary(dictionary: ["AXTrustedCheckOptionPrompt": NSNumber(value: true)])
        _ = AXIsProcessTrustedWithOptions(options)
        refreshAccessibilityStatus()
    }

    /// Opens a Finder window with **this build’s** `Contexts.app` selected so you can add it via **+** in
    /// System Settings → Accessibility (especially when running from Xcode / DerivedData).
    func revealApplicationInFinder() {
        let url = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
