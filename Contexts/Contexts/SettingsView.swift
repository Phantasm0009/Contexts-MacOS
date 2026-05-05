import AppKit
import ServiceManagement
import SwiftUI

/// App preferences (standard macOS Settings window, ⌘,).
struct SettingsView: View {
    @State private var launchAtLogin = false

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
            Toggle("Launch at login", isOn: launchAtLoginBinding)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

#Preview {
    SettingsView()
}
