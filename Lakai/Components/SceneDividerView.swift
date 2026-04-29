import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SceneDividerView: View {
    let divider: SceneDivider
    let sceneNumber: Int
    let isDragged: Bool
    let onDelete: () -> Void
    let onTitleChange: (String) -> Void
    let onContextMenuRequest: (CGPoint) -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LakaiTheme.mutedInk)
                .frame(width: 18)

            // Scene badge
            Text("Szene \(sceneNumber)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LakaiTheme.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(LakaiTheme.accentStrong)
                .clipShape(Capsule())

            // Editable title
            TextField("Szenenbeschreibung", text: Binding(
                get: { divider.title },
                set: { onTitleChange($0) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(LakaiTheme.ink)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                LakaiTheme.accentSoft.opacity(0.55)
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(LakaiTheme.panelBorder)
                        .frame(height: 1)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isDragged ? LakaiTheme.ink.opacity(0.9) : LakaiTheme.panelBorder.opacity(0.5), lineWidth: isDragged ? 2 : 1)
        )
        .scaleEffect(isDragged ? 1.01 : 1)
        .overlay(
            RightClickCaptureView { point in
                onContextMenuRequest(point)
            }
        )
    }
}
