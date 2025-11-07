import SwiftUI
import SwiftData

@main
struct CX_UK_InductionApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: Visitor.self)
                .environment(VisitorStore())
        }
    }
}
