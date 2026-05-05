import AppKit
import ServiceManagement
import SwiftUI

/// App preferences (standard macOS Settings window, ⌘,).
struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var licenseManager: LicenseManager
    @EnvironmentObject private var permissionsManager: PermissionsManager
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var launchAtLogin = false
    @AppStorage(ContextsPreferences.hideUnassociatedAppsOnRunKey) private var hideUnassociatedAppsOnRun = false

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                if newValue {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        )
    }

    var body: some View {
        Form {
            Section("License") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(licenseStatusLabel)
                        .foregroundStyle(licenseStatusColor)
                }
                Button("Manage License...") {
                    openWindow(id: ContextsApp.licenseWindowID)
                }
            }

            Section("App Behavior") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                Toggle("Close (hide) apps not in context when running", isOn: $hideUnassociatedAppsOnRun)
                Text("When enabled, apps not included in the selected context are hidden after launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Permissions") {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    Text(permissionsManager.isAccessibilityTrusted ? "Granted" : "Not Granted")
                        .foregroundStyle(permissionsManager.isAccessibilityTrusted ? .green : .orange)
                }
                HStack {
                    Button("Open Accessibility Settings") {
                        permissionsManager.openAccessibilitySettings()
                    }
                    Button("Refresh") {
                        permissionsManager.refreshAccessibilityStatus()
                    }
                }
            }

            Section("Session") {
                HStack {
                    Text("Active Context")
                    Spacer()
                    Text(sessionManager.activeContext?.name ?? "None")
                        .foregroundStyle(.secondary)
                }
                Button("Clear Active Context", role: .destructive) {
                    sessionManager.clearActiveSession()
                }
                .disabled(sessionManager.activeContext == nil)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin = SMAppService.mainApp.status == .enabled
            permissionsManager.refreshAccessibilityStatus()
        }
    }

    private var licenseStatusLabel: String {
        switch licenseManager.status {
        case .active:
            return "Activated"
        case .expired:
            return "Trial Expired"
        case .trial(let daysRemaining):
            return "Trial (\(daysRemaining)d left)"
        }
    }

    private var licenseStatusColor: Color {
        switch licenseManager.status {
        case .active:
            return .green
        case .expired:
            return .orange
        case .trial:
            return .secondary
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LicenseManager())
        .environmentObject(PermissionsManager())
        .environmentObject(SessionManager())
}
