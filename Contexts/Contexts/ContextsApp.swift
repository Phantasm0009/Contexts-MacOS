import SwiftData
import SwiftUI

@main
struct ContextsApp: App {
    /// Shared identifier for `WindowGroup` and `openWindow(id:)`.
    static let dashboardWindowID = "dashboard"
    static let licenseWindowID = "license"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var permissionsManager = PermissionsManager()
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var licenseManager = LicenseManager()

    var body: some Scene {
        WindowGroup(id: Self.dashboardWindowID) {
            DashboardView()
                .environmentObject(permissionsManager)
                .environmentObject(sessionManager)
                .environmentObject(licenseManager)
        }
        .modelContainer(SharedModelContainer.shared)

        MenuBarExtra {
            MenuBarExtraContentView()
                .environmentObject(sessionManager)
                .environmentObject(licenseManager)
        } label: {
            Label(
                "Contexts",
                systemImage: sessionManager.activeContext != nil ? "square.stack.3d.up.fill" : "square.stack.3d.up"
            )
        }
        .menuBarExtraStyle(.window)
        .modelContainer(SharedModelContainer.shared)

        Settings {
            SettingsView()
        }

        Window("License", id: Self.licenseWindowID) {
            LicenseView()
                .environmentObject(licenseManager)
        }
    }
}
