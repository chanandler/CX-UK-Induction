import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        ZStack {
            Color.cemexBlue
                .ignoresSafeArea()

            WelcomeView()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}
