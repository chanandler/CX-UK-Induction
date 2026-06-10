import SwiftUI
import SwiftData

@main
struct CX_UK_InductionApp: App {
    private enum LaunchState {
        case persistent(ModelContainer)
        case inMemory(ModelContainer, message: String)
        case failed(message: String)
    }

    private let launchState: LaunchState

    init() {
        do {
            let persistent = try ModelContainer(
                for: Visitor.self,
                PreRegisteredVisitor.self,
                StaffPagerIssue.self
            )
            launchState = .persistent(persistent)
        } catch let persistentError {
            do {
                let inMemoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
                let fallback = try ModelContainer(
                    for: Visitor.self,
                    PreRegisteredVisitor.self,
                    StaffPagerIssue.self,
                    configurations: inMemoryConfiguration
                )
                launchState = .inMemory(
                    fallback,
                    message: "Persistent storage could not be opened. The app is running in temporary in-memory mode. Data will not persist after the app closes."
                )
                print("SwiftData persistent store failed, running in-memory fallback:", persistentError)
            } catch let fallbackError {
                launchState = .failed(
                    message: "The app could not start its data store. Please restart the app or contact support.\n\nPersistent error: \(persistentError.localizedDescription)\nFallback error: \(fallbackError.localizedDescription)"
                )
                print("SwiftData failed for both persistent and in-memory stores:", persistentError, fallbackError)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            appRoot
                .environment(VisitorStore())
        }
    }

    @ViewBuilder
    private var appRoot: some View {
        switch launchState {
        case .persistent(let container):
            RootView()
                .modelContainer(container)
        case .inMemory(let container, let message):
            RootView()
                .modelContainer(container)
                .overlay(alignment: .top) {
                    StartupWarningBanner(message: message)
                }
        case .failed(let message):
            DataStoreStartupErrorView(message: message)
        }
    }
}

private struct StartupWarningBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.96))
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 1),
                alignment: .bottom
            )
    }
}

private struct DataStoreStartupErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange)
                Text("Startup Error")
                    .font(.title2.bold())
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }
}
