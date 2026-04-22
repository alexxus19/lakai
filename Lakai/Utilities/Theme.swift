import Foundation
import SwiftUI

enum LakaiTheme {
    static let canvas = Color(red: 0.07, green: 0.09, blue: 0.12)
    static let canvasAlt = Color(red: 0.11, green: 0.14, blue: 0.19)
    static let panel = Color(red: 0.14, green: 0.18, blue: 0.24)
    static let panelElevated = Color(red: 0.17, green: 0.22, blue: 0.29)
    static let panelBorder = Color(red: 0.32, green: 0.38, blue: 0.47)
    static let ink = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let mutedInk = Color(red: 0.73, green: 0.79, blue: 0.86)
    static let accent = Color(red: 0.33, green: 0.56, blue: 0.73)
    static let accentSoft = Color(red: 0.20, green: 0.27, blue: 0.35)
    static let accentStrong = Color(red: 0.25, green: 0.46, blue: 0.62)
    static let success = Color(red: 0.33, green: 0.57, blue: 0.45)
    static let warning = Color(red: 0.70, green: 0.52, blue: 0.30)

    // Shot card background colors (6 subtly different, readable colors)
    static let shotColors: [(hex: String, color: Color)] = [
        ("C8E6C9", Color(red: 0.78, green: 0.90, blue: 0.79)),  // Pale mint
        ("FFCCBC", Color(red: 1.00, green: 0.80, blue: 0.74)),  // Soft peach
        ("B3E5FC", Color(red: 0.70, green: 0.90, blue: 0.99)),  // Light sky
        ("F8BBD0", Color(red: 0.97, green: 0.73, blue: 0.82)),  // Soft rose
        ("FFF9C4", Color(red: 1.00, green: 0.97, blue: 0.77)),  // Warm cream
        ("D1C4E9", Color(red: 0.82, green: 0.77, blue: 0.91))   // Soft lavender
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