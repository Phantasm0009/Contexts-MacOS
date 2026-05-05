import SwiftData
import SwiftUI

private struct ContextsCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var sessionManager: SessionManager

    var body: some Commands {
        CommandMenu("Contexts") {
            Button("Open Dashboard") {
                openWindow(id: ContextsApp.dashboardWindowID)
            }
            .keyboardShortcut("d", modifiers: [.command, .option])

            Button("License...") {
                openWindow(id: ContextsApp.licenseWindowID)
            }
            .keyboardShortcut("l", modifiers: [.command, .option])

            Divider()

            if shortcutEntries.isEmpty {
                Text("No contexts available")
            } else {
                ForEach(shortcutEntries) { entry in
                    Button(entry.context.name) {
                        Task {
                            await sessionManager.run(context: entry.context)
                        }
                    }
                    .keyboardShortcut(entry.key, modifiers: [.option])
                }
            }
        }
    }

    private var shortcutEntries: [ShortcutEntry] {
        let modelContext = ModelContext(SharedModelContainer.shared)
        let descriptor = FetchDescriptor<WorkContext>()
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        let orderedByUser = all.sorted {
            let a = $0.orderIndex ?? Int.max
            let b = $1.orderIndex ?? Int.max
            if a != b { return a < b }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        let ordered = orderedByUser.filter(\.isPinned) + orderedByUser.filter { !$0.isPinned }
        return ordered.prefix(9).enumerated().compactMap { idx, context in
            guard let key = keyEquivalent(forSlot: idx + 1) else { return nil }
            return ShortcutEntry(context: context, key: key)
        }
    }

    private func keyEquivalent(forSlot slot: Int) -> KeyEquivalent? {
        switch slot {
        case 1: return "1"
        case 2: return "2"
        case 3: return "3"
        case 4: return "4"
        case 5: return "5"
        case 6: return "6"
        case 7: return "7"
        case 8: return "8"
        case 9: return "9"
        default: return nil
        }
    }

    private struct ShortcutEntry: Identifiable {
        let context: WorkContext
        let key: KeyEquivalent
        var id: UUID { context.id }
    }
}

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
        .commands {
            ContextsCommands(sessionManager: sessionManager)
        }

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
                .environmentObject(licenseManager)
                .environmentObject(permissionsManager)
                .environmentObject(sessionManager)
        }

        Window("License", id: Self.licenseWindowID) {
            LicenseView()
                .environmentObject(licenseManager)
        }

    }
}
