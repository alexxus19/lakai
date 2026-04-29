import AppKit
import SwiftUI

// Configures the underlying NSWindow so the title bar is always transparent,
// letting the canvas gradient show behind the traffic-light buttons.
private struct WindowTitleBarConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(LakaiTheme.canvas)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(LakaiTheme.canvas)
    }
}

struct RootView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        ZStack {
            WindowTitleBarConfigurator()
                .frame(width: 0, height: 0)

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