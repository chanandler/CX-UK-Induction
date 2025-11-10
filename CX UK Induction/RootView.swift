import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(alignment: .center, spacing: 12) {
                Text("Welcome to Cemex UK HQ")
                    .font(.system(size: 48, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                WelcomeView()
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    RootView()
}
