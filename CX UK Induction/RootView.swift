import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        NavigationSplitView {
            WelcomeView()
                .navigationTitle("Induction")
        } detail: {
            VisitorTabs()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}
