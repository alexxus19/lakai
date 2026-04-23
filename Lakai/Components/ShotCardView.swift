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
    @State private var isSizePickerPresented = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            metadataColumn
                .frame(width: 88, alignment: .leading)
                .contentShape(Rectangle())
                .contextMenu {
                    contextMenuContent
                }

            VStack(alignment: .leading, spacing: 7) {
                TextEditor(text: descriptionBinding)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(LakaiTheme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 52, maxHeight: 64)
                    .background(LakaiTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LakaiTheme.panelBorder, lineWidth: 1))

                TextField("Anmerkungen / Kameramoves", text: notesBinding)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
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
        .padding(12)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LakaiTheme.panelBorder, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .contextMenu {
            contextMenuContent
        }
        .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 6)
    }

    private var metadataColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("#\(shotNumber)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LakaiTheme.ink)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Groesse")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(LakaiTheme.mutedInk)
                    .textCase(.uppercase)

                Button {
                    isSizePickerPresented.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(sizeBinding.wrappedValue.title)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LakaiTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isSizePickerPresented, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(ShotSize.allCases) { size in
                            Button {
                                sizeBinding.wrappedValue = size
                                isSizePickerPresented = false
                            } label: {
                                HStack {
                                    Text(size.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.white)

                                    Spacer(minLength: 0)

                                    if sizeBinding.wrappedValue == size {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.white)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(LakaiTheme.panel.opacity(0.96))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .frame(width: 190)
                    .background(LakaiTheme.canvas)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
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
        Group {
            Button(action: onToggleOptional) {
                Label(shot.isOptional ? "Als normal markieren" : "Als optional markieren", systemImage: shot.isOptional ? "checkmark.circle.fill" : "circle")
            }

            Menu {
                ForEach(LakaiTheme.shotColors, id: \.hex) { item in
                    Button {
                        onSetBackgroundColor(item.hex)
                    } label: {
                        Label(colorName(for: item.hex), systemImage: "circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(item.color, Color.primary)
                    }
                }

                Divider()

                Button {
                    onSetBackgroundColor(nil)
                } label: {
                    Label("Farbe entfernen", systemImage: "xmark.circle")
                }
            } label: {
                Label("Farbe", systemImage: "paintpalette")
            }

            Divider()

            Button(action: onDuplicate) {
                Label("Duplizieren", systemImage: "square.on.square")
            }

            if mode == .shotlist {
                Divider()

                Button(role: .destructive, action: onDelete) {
                    Label("Shot loeschen", systemImage: "trash")
                }
            }
        }
    }

    private func colorName(for hex: String) -> String {
        let normalizedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        switch normalizedHex {
        case "BFE8D2": return "Mint"
        case "F6D3C6": return "Peach"
        case "C7DEF4": return "Sky"
        case "F2C8D8": return "Rose"
        case "F7ECC6": return "Cream"
        case "DDD3F8": return "Lavender"
        default: return "Farbe"
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
        .contextMenu {
            contextMenuContent
        }
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