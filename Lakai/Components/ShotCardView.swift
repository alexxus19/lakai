import AppKit
import SwiftUI

private enum AssetImageCache {
    static let shared: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 512
        return cache
    }()
}

struct CachedAssetImageView<Placeholder: View>: View {
    let imageURL: URL?
    let contentMode: ContentMode
    let placeholder: () -> Placeholder

    @State private var image: NSImage?

    init(imageURL: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.imageURL = imageURL
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: imageURL?.standardizedFileURL.path ?? "") {
            loadImage()
        }
    }

    private func loadImage() {
        guard let imageURL else {
            image = nil
            return
        }

        let normalizedURL = imageURL.standardizedFileURL
        let key = normalizedURL as NSURL
        if let cachedImage = AssetImageCache.shared.object(forKey: key) {
            image = cachedImage
            return
        }

        image = nil
        let requestedPath = normalizedURL.path
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = NSImage(contentsOf: normalizedURL)
            if let loadedImage {
                AssetImageCache.shared.setObject(loadedImage, forKey: key)
            }

            DispatchQueue.main.async {
                guard self.imageURL?.standardizedFileURL.path == requestedPath else {
                    return
                }
                self.image = loadedImage
            }
        }
    }
}

struct ShotCardView: View {
    let shotNumber: String
    let shot: Shot
    let imageURL: URL?
    let mode: WorkspaceMode
    let onDelete: () -> Void
    let onImportImage: () -> Void
    let onRemoveImage: () -> Void
    let onToggleOptional: () -> Void
    let onSetBackgroundColor: (String?) -> Void
    let onDuplicate: () -> Void
    let sizeBinding: Binding<ShotSize>
    let descriptionBinding: Binding<String>
    let notesBinding: Binding<String>
    let setupBinding: Binding<String>
    let durationBinding: Binding<String>

    @State private var isHoveringImage = false
    @State private var isShowingColorPicker = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("#\(shotNumber)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LakaiTheme.ink)

                    Menu {
                        ForEach(ShotSize.allCases) { size in
                            Button(size.title) {
                                sizeBinding.wrappedValue = size
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(sizeBinding.wrappedValue.title)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LakaiTheme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(LakaiTheme.accentSoft)
                        .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                    .tint(LakaiTheme.ink)

                    Spacer()

                    if mode == .shotlist {
                        iconButton("trash") { onDelete() }
                    }
                }

                TextEditor(text: descriptionBinding)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(LakaiTheme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(7)
                    .frame(minHeight: 62, maxHeight: 74)
                    .background(LakaiTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LakaiTheme.panelBorder, lineWidth: 1))

                TextField("Anmerkungen / Kameramoves", text: notesBinding)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(LakaiTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(LakaiTheme.ink)
                    .font(.system(size: 11, weight: .regular))

                if mode == .schedule {
                    HStack(spacing: 10) {
                        labeledField(title: "Setup", text: setupBinding, width: 96)
                        labeledField(title: "Dauer", text: durationBinding, width: 96)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            imagePanel
        }
        .padding(14)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LakaiTheme.panelBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 6)
        .contextMenu {
            contextMenuContent
        }
    }

    private var cardBackgroundColor: Color {
        if let colorHex = shot.backgroundColor {
            if let color = colorFromHex(colorHex) {
                return color.opacity(0.55)
            }
        }
        return LakaiTheme.panel.opacity(0.96)
    }

    private var contextMenuContent: some View {
        VStack {
            Button(action: onToggleOptional) {
                Label(shot.isOptional ? "Aktivieren" : "Optional", systemImage: shot.isOptional ? "checkmark.circle.fill" : "circle")
            }

            Divider()

            Menu {
                HStack(spacing: 12) {
                    Spacer()
                    ForEach(LakaiTheme.shotColors, id: \.hex) { item in
                        Button(action: { onSetBackgroundColor(item.hex) }) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(shot.backgroundColor == item.hex ? LakaiTheme.ink : Color.clear, lineWidth: 2))
                        }
                    }
                    Button(action: { onSetBackgroundColor(nil) }) {
                        Image(systemName: "xmark")
                            .foregroundStyle(LakaiTheme.mutedInk)
                            .frame(width: 26, height: 26)
                            .background(LakaiTheme.accentSoft)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(12)
            } label: {
                Label("Farbe", systemImage: "paintpalette")
            }

            Divider()

            Button(action: onDuplicate) {
                Label("Duplizieren", systemImage: "square.on.square")
            }
        }
    }

    private func colorFromHex(_ hex: String) -> Color? {
        let trimmed = hex.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count == 6 else { return nil }

        let scanner = Scanner(string: trimmed)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        return Color(red: red, green: green, blue: blue)
    }

    private var imagePanel: some View {
        let content = ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LakaiTheme.canvasAlt.opacity(0.7))

            if let imageURL {
                CachedAssetImageView(imageURL: imageURL, contentMode: .fill) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(LakaiTheme.mutedInk)
                        Text("Bild laden...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(LakaiTheme.mutedInk)
                    }
                }
                .frame(width: 232, height: 130)
                .clipped()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(LakaiTheme.mutedInk)
                    Text(mode == .shotlist ? "Bild hinzufügen" : "Kein Bild")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LakaiTheme.mutedInk)
                }
            }

            if mode == .shotlist {
                Color.black.opacity(isHoveringImage ? 0.16 : 0)

                VStack(spacing: 8) {
                    if imageURL != nil && isHoveringImage {
                        overlayButton(title: "Bild ändern", action: onImportImage)
                        overlayButton(title: "Entfernen", action: onRemoveImage)
                    }
                }
                .opacity(isHoveringImage ? 1 : 0)
                .animation(.easeInOut(duration: 0.16), value: isHoveringImage)
            }
        }
        .frame(width: 232, height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LakaiTheme.panelBorder, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onHover { hovering in
            guard mode == .shotlist else {
                return
            }

            isHoveringImage = hovering
        }

        if mode == .shotlist {
            return AnyView(
                Button(action: onImportImage) {
                    content
                }
                .buttonStyle(.plain)
            )
        }

        return AnyView(content)
    }

    private func overlayButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title) {
            action()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(LakaiTheme.accentStrong)
    }

    private func iconButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .background(LakaiTheme.accentSoft)
        .clipShape(Circle())
    }

    private func labeledField(title: String, text: Binding<String>, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LakaiTheme.ink)

            TextField(title, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(LakaiTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(LakaiTheme.ink)
                .font(.system(size: 12, weight: .medium))
                .frame(width: width)
        }
    }
}