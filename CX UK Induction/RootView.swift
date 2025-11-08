import SwiftUI
import SwiftData

struct RootView: View {
    // CEMEX Blue: HEX #023185 (RGB 2,49,133)
    private let cemexBlue = Color(red: 2/255, green: 49/255, blue: 133/255)

    var body: some View {
        NavigationSplitView {
            // LEFT (SIDEBAR) COLUMN
            ZStack(alignment: .trailing) {
                // Full-bleed pure white so nothing shows through from the detail pane.
                Color.white
                    .ignoresSafeArea(edges: .all)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Welcome to Cemex UK HQ")
                        .font(.system(size: 48, weight: .bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    WelcomeView()
                }
                .padding(.horizontal)

                // Edge-to-edge divider to fully cover any split-view gutter.
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1)
                    .ignoresSafeArea(edges: .vertical)
            }
            .navigationSplitViewColumnWidth(min: 480, ideal: 520, max: 600)
            // Suppress any auto-added sidebar toggle button.
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    // Intentionally empty
                }
            }
        } detail: {
            // RIGHT (DETAIL) COLUMN
            ZStack {
                cemexBlue.ignoresSafeArea()
                VisitorTabs()
            }
            .background(cemexBlue)
            // Suppress auto-added leading items (e.g., sidebar toggle) in detail too.
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    // Intentionally empty
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    RootView()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}
