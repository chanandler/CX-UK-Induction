import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            WelcomeView()
        }
    }
}

#Preview {
    RootView()
}
