import AppIntents

/// Registers natural-language shortcuts so Spotlight / Siri / Shortcuts can run contexts by name.
///
/// Avoid “Switch to …” phrases—the gallery can summarize them oddly on some OS versions.
///
/// Phrases must use `AppShortcutPhrase<LaunchSavedContextIntent>(…)` so `\(\.$context)` uses App Intents interpolation.
struct ContextsAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LaunchSavedContextIntent(),
            phrases: [
                AppShortcutPhrase("Run \(\.$context) in \(.applicationName)"),
                AppShortcutPhrase("Start \(\.$context) in \(.applicationName)"),
            ],
            shortTitle: LocalizedStringResource("Run Context"),
            systemImageName: "play.circle.fill"
        )
    }
}
