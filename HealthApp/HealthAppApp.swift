import SwiftUI
import SwiftData

@main
struct HealthAppApp: App {
    @StateObject private var storeLauncher = PersistentStoreLauncher()

    var body: some Scene {
        WindowGroup {
            AppLaunchRoot(launcher: storeLauncher)
                .preferredColorScheme(.dark)
        }
    }
}

private struct AppLaunchRoot: View {
    @ObservedObject var launcher: PersistentStoreLauncher

    var body: some View {
        switch launcher.phase {
        case .ready(let container):
            AppRootView()
                .modelContainer(container)
        case .needsRecovery(let error):
            DatabaseRecoveryView(error: error) {
                launcher.eraseStoreAndRecreate()
            }
        }
    }
}
