import SwiftData

/// Single on-disk store shared by SwiftUI scenes and App Intents (`LaunchSavedContextIntent`).
enum SharedModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            WorkContext.self,
            AppResource.self,
            WebResource.self,
            WindowSnapshot.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }()
}

