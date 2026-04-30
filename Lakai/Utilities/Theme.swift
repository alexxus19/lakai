import AppKit
import Foundation
import SwiftUI

// MARK: - ThemeDefinition

struct ThemeDefinition {
    var canvas: Color
    var canvasAlt: Color
    var panel: Color
    var panelElevated: Color
    var panelBorder: Color
    var ink: Color
    var mutedInk: Color
    var accent: Color
    var accentSoft: Color
    var accentStrong: Color
    var success: Color
    var warning: Color
    var fontFamily: String
    var colorScheme: ColorScheme

    var nsInk: NSColor { NSColor(ink) }
    var nsMutedInk: NSColor { NSColor(mutedInk) }
    var nsCanvas: NSColor { NSColor(canvas) }

    // MARK: - Built-in fallbacks

    static let dark = ThemeDefinition(
        canvas:        Color(red: 0.07, green: 0.09, blue: 0.12),
        canvasAlt:     Color(red: 0.11, green: 0.14, blue: 0.19),
        panel:         Color(red: 0.14, green: 0.18, blue: 0.24),
        panelElevated: Color(red: 0.17, green: 0.22, blue: 0.29),
        panelBorder:   Color(red: 0.32, green: 0.38, blue: 0.47),
        ink:           Color(red: 0.95, green: 0.97, blue: 0.99),
        mutedInk:      Color(red: 0.73, green: 0.79, blue: 0.86),
        accent:        Color(red: 0.33, green: 0.56, blue: 0.73),
        accentSoft:    Color(red: 0.20, green: 0.27, blue: 0.35),
        accentStrong:  Color(red: 0.25, green: 0.46, blue: 0.62),
        success:       Color(red: 0.33, green: 0.57, blue: 0.45),
        warning:       Color(red: 0.70, green: 0.52, blue: 0.30),
        fontFamily:    "system",
        colorScheme:   .dark
    )

    static let light = ThemeDefinition(
        canvas:        Color(red: 0.961, green: 0.941, blue: 0.910),
        canvasAlt:     Color(red: 0.929, green: 0.910, blue: 0.875),
        panel:         Color(red: 0.992, green: 0.980, blue: 0.961),
        panelElevated: Color(red: 1.000, green: 1.000, blue: 1.000),
        panelBorder:   Color(red: 0.808, green: 0.784, blue: 0.749),
        ink:           Color(red: 0.102, green: 0.090, blue: 0.071),
        mutedInk:      Color(red: 0.478, green: 0.455, blue: 0.408),
        accent:        Color(red: 0.239, green: 0.220, blue: 0.188),
        accentSoft:    Color(red: 0.929, green: 0.910, blue: 0.875),
        accentStrong:  Color(red: 0.165, green: 0.145, blue: 0.125),
        success:       Color(red: 0.239, green: 0.420, blue: 0.306),
        warning:       Color(red: 0.545, green: 0.376, blue: 0.125),
        fontFamily:    "system",
        colorScheme:   .light
    )
}

// MARK: - ThemeManager

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var current: ThemeDefinition = .light

    private init() {}

    func load(named name: String) {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "xml"),
            let data = try? Data(contentsOf: url)
        else {
            current = (name == "dark") ? .dark : .light
            return
        }

        let parser = ThemeXMLParser()
        if let parsed = parser.parse(data: data) {
            current = parsed
        } else {
            current = (name == "dark") ? .dark : .light
        }
    }
}

// MARK: - ThemeXMLParser

private final class ThemeXMLParser: NSObject, XMLParserDelegate {
    private var colors: [String: String] = [:]
    private var fontFamily = "system"
    private var colorSchemeName = "light"

    func parse(data: Data) -> ThemeDefinition? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }
        return buildTheme()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "color":
            if let name = attributeDict["name"], let hex = attributeDict["hex"] {
                colors[name] = hex
            }
        case "font":
            fontFamily = attributeDict["family"] ?? "system"
        case "theme":
            colorSchemeName = attributeDict["colorScheme"] ?? "light"
        default:
            break
        }
    }

    private func buildTheme() -> ThemeDefinition? {
        func color(_ name: String, fallback: Color) -> Color {
            guard let hex = colors[name] else { return fallback }
            return Color(hex: hex) ?? fallback
        }

        let scheme: ColorScheme = (colorSchemeName == "dark") ? .dark : .light

        return ThemeDefinition(
            canvas:        color("canvas",        fallback: .primary),
            canvasAlt:     color("canvasAlt",     fallback: .primary),
            panel:         color("panel",          fallback: .primary),
            panelElevated: color("panelElevated",  fallback: .primary),
            panelBorder:   color("panelBorder",    fallback: .secondary),
            ink:           color("ink",            fallback: .primary),
            mutedInk:      color("mutedInk",       fallback: .secondary),
            accent:        color("accent",         fallback: .accentColor),
            accentSoft:    color("accentSoft",     fallback: .secondary),
            accentStrong:  color("accentStrong",   fallback: .accentColor),
            success:       color("success",        fallback: .green),
            warning:       color("warning",        fallback: .orange),
            fontFamily:    fontFamily,
            colorScheme:   scheme
        )
    }
}

// MARK: - Color hex initialiser

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        guard cleaned.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&rgb) else { return nil }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >>  8) & 0xFF) / 255.0,
            blue:  Double( rgb        & 0xFF) / 255.0
        )
    }
}

// MARK: - LakaiTheme (shot & cast colors — theme-independent)

enum LakaiTheme {
    // Shot card background colors (6 subtly different, readable colors)
    static let shotColors: [(hex: String, color: Color)] = [
        ("C8E6C9", Color(red: 0.78, green: 0.90, blue: 0.79)),  // Pale mint
        ("FFCCBC", Color(red: 1.00, green: 0.80, blue: 0.74)),  // Soft peach
        ("B3E5FC", Color(red: 0.70, green: 0.90, blue: 0.99)),  // Light sky
        ("F8BBD0", Color(red: 0.97, green: 0.73, blue: 0.82)),  // Soft rose
        ("FFF9C4", Color(red: 1.00, green: 0.97, blue: 0.77)),  // Warm cream
        ("D1C4E9", Color(red: 0.82, green: 0.77, blue: 0.91))   // Soft lavender
    ]

    // Cast member chip colors — vivid, high-contrast with white text on dark panels.
    static let castColors: [(hex: String, color: Color, name: String)] = [
        ("D64545", Color(red: 0.84, green: 0.27, blue: 0.27), "Rot"),
        ("C47B1A", Color(red: 0.77, green: 0.48, blue: 0.10), "Orange"),
        ("2E8B57", Color(red: 0.18, green: 0.55, blue: 0.34), "Grün"),
        ("2A6EBB", Color(red: 0.16, green: 0.43, blue: 0.73), "Blau"),
        ("6B46C1", Color(red: 0.42, green: 0.27, blue: 0.76), "Lila"),
        ("B5386C", Color(red: 0.71, green: 0.22, blue: 0.42), "Pink")
    ]
}


enum LakaiFormatters {
    static let libraryDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let exportDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let shootDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return formatter
    }()

    static func durationString(from seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }

    static func timeString(from secondsFromMidnight: Int) -> String {
        let hours = (secondsFromMidnight / 3600) % 24
        let minutes = (secondsFromMidnight % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    static func parseDuration(_ rawValue: String) -> Int? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":")
            guard parts.count == 2,
                  let hours = Int(parts[0]),
                  let minutes = Int(parts[1]) else {
                return nil
            }

            return (hours * 3600) + (minutes * 60)
        }

        if let minutes = Int(trimmed) {
            return minutes * 60
        }

        return nil
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }

        var chunks: [[Element]] = []
        var startIndex = 0

        while startIndex < count {
            let endIndex = Swift.min(startIndex + size, count)
            chunks.append(Array(self[startIndex..<endIndex]))
            startIndex += size
        }

        return chunks
    }
}

extension String {
    var fileNameSafe: String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let components = components(separatedBy: invalidCharacters)
        return components.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}