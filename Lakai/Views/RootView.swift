import SwiftUI

struct RootView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        ZStack {
            if appState.activeProject == nil {
                OverviewView(appState: appState)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            }

            if appState.activeProject != nil {
                WorkspaceView(appState: appState)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity.combined(with: .scale(scale: 0.98))))
            }
        }
        .frame(minWidth: 1220, minHeight: 820)
        .animation(.snappy(duration: 0.34, extraBounce: 0.04), value: appState.activeProject?.id)
        .alert("Lakai", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                appState.errorMessage = nil
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}