import SwiftUI
import SwiftData

@main
struct CX_UK_InductionApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Visitor.self)
        } catch {
            fatalError("Failed to initialise SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environment(VisitorStore())
        }
    }
}
