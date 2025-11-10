import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        ZStack {
            Color(red: 2/255, green: 49/255, blue: 133/255)
                .ignoresSafeArea()

            GeometryReader { geo in
                VStack(alignment: .center, spacing: 12) {
                    WelcomeView()
                }
                .padding(.horizontal)
                .frame(maxWidth: 540)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .frame(width: geo.size.width, height: geo.size.height)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }
}

#Preview {
    RootView()
}
