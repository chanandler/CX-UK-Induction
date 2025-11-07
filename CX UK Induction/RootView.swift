import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to Cemex UK HQ")
                    .font(.system(size: 48, weight: .bold))
                    .padding(.top, 8)
                WelcomeView()
            }
            .padding(.horizontal)
            .navigationSplitViewColumnWidth(min: 480, ideal: 520, max: 600)
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
