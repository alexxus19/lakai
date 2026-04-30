import SwiftUI

@main
struct LakaiApp: App {
    init() {
        ThemeManager.shared.load(named: "light")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(ThemeManager.shared)
        }
        .windowResizability(.contentSize)
    }
}