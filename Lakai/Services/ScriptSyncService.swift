import AppKit
import Foundation

struct ScriptSyncResult {
    let scriptText: String
    let shots: [Shot]
    let shotOrder: [UUID]
    let scheduleBlocks: [ScheduleBlock]
}

struct ScriptSyncService {
    func parseScript(_ scriptText: String, preserving existingProject: ProjectDocument) -> ScriptSyncResult {
        let lines = scriptText.components(separatedBy: .newlines)
        var parsedEntries: [(description: String, notes: String, size: ShotSize)] = []
        var currentDescription: String?
        var currentNotes: [String] = []
        var hasStartedShots = false

        for line in lines {
            if let descriptionLine = shotDescriptionLine(from: line) {
                hasStartedShots = true

                if let currentDescription {
                    parsedEntries.append((currentDescription, collapseNotes(currentNotes), detectShotSize(in: currentDescription).size))
                }

                currentDescription = descriptionLine
                currentNotes = []
                continue
            }

            guard hasStartedShots, currentDescription != nil else {
                continue
            }

            currentNotes.append(line)
        }

        if let currentDescription {
            parsedEntries.append((currentDescription, collapseNotes(currentNotes), detectShotSize(in: currentDescription).size))
        }

        let existingShotsByIndex = Array(existingProject.orderedShots.enumerated())
        var shots: [Shot] = []
        var shotOrder: [UUID] = []
        var scheduleBlocks: [ScheduleBlock] = []

        for (index, entry) in parsedEntries.enumerated() {
            let sizeMatch = detectShotSize(in: entry.description)
            var shot = existingShotsByIndex.indices.contains(index) ? existingShotsByIndex[index].element : Shot()
            shot.size = sizeMatch.size
            shot.descriptionText = sizeMatch.cleanedDescription
            shot.notes = entry.notes
            shots.append(shot)
            shotOrder.append(shot.id)

            let existingBlock = existingProject.orderedScheduleBlocks.first(where: { $0.shotID == shot.id && $0.kind == .shot })
            scheduleBlocks.append(
                ScheduleBlock(
                    id: existingBlock?.id ?? UUID(),
                    kind: .shot,
                    shotID: shot.id,
                    title: "",
                    durationSeconds: 0,
                    scheduleNotes: existingBlock?.scheduleNotes ?? ""
                )
            )
        }

        let pauseBlocks = existingProject.orderedScheduleBlocks.filter { $0.kind == .pause }
        scheduleBlocks.append(contentsOf: pauseBlocks)

        return ScriptSyncResult(
            scriptText: scriptText,
            shots: shots,
            shotOrder: shotOrder,
            scheduleBlocks: scheduleBlocks
        )
    }

    func composeScript(from project: ProjectDocument) -> String {
        project.orderedShots.map { shot in
            let description = shot.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            let headline = description.isEmpty ? shot.size.scriptKeyword : "\(shot.size.scriptKeyword) \(description)"
            let notes = shot.notes.trimmingCharacters(in: .whitespacesAndNewlines)

            if notes.isEmpty {
                return "• \(headline)"
            }

            return "• \(headline)\n\(notes)"
        }
        .joined(separator: "\n\n")
    }

    func attributedScript(_ text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        let nsText = text as NSString
        let lines = text.components(separatedBy: .newlines)
        var location = 0

        for line in lines {
            let range = NSRange(location: location, length: line.count)

            if let descriptionLine = shotDescriptionLine(from: line) {
                let matched = detectShotSize(in: descriptionLine)
                let keyword = matched.keyword
                if !keyword.isEmpty, let keywordRange = line.range(of: keyword, options: [.caseInsensitive]) {
                    let nsRange = NSRange(keywordRange, in: line)
                    attributed.addAttributes(keywordAttributes, range: NSRange(location: location + nsRange.location, length: nsRange.length))
                }
                attributed.addAttributes(shotLineAttributes, range: range)
            }

            location += nsText.substring(with: range).count + 1
        }

        return attributed
    }

    private func shotDescriptionLine(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let checklistLine = stripChecklistPrefix(from: trimmed) {
            let normalized = normalizeImportedDescription(checklistLine)
            return normalized.isEmpty ? nil : normalized
        }

        let markerPrefixes = ["•", "#", "-", "*"]
        for prefix in markerPrefixes where trimmed.hasPrefix(prefix) {
            let description = normalizeImportedDescription(String(trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)))
            return description.isEmpty ? nil : String(description)
        }

        if trimmed.hasPrefix("[") {
            let cleaned = normalizeImportedDescription(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "[] ")))
            return cleaned.isEmpty ? nil : cleaned
        }

        return nil
    }

    private func detectShotSize(in description: String) -> (size: ShotSize, cleanedDescription: String, keyword: String) {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = splitLeadingLabels(from: trimmed)
        let searchableText = prefixes.remainingText

        for (keyword, size) in ShotSize.scriptKeywordMatchers {
            if searchableText.lowercased().hasPrefix(keyword) {
                var cleaned = String(searchableText.dropFirst(keyword.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ":,- "))
                let combined = prefixes.labels.isEmpty ? cleaned : ([prefixes.labels, cleaned].filter { !$0.isEmpty }.joined(separator: " "))
                return (size, combined.isEmpty ? trimmed : combined, String(searchableText.prefix(keyword.count)))
            }
        }

        return (.ms, trimmed, "")
    }

    private func stripChecklistPrefix(from line: String) -> String? {
        let characters = Array(line)
        guard characters.count >= 5,
              (characters[0] == "-" || characters[0] == "*"),
              characters[1].isWhitespace,
              characters[2] == "[" else {
            return nil
        }

        guard let closingBracketIndex = line.firstIndex(of: "]") else {
            return nil
        }

        let remainder = line[line.index(after: closingBracketIndex)...].trimmingCharacters(in: .whitespaces)
        return remainder.isEmpty ? nil : remainder
    }

    private func normalizeImportedDescription(_ description: String) -> String {
        var normalized = description.trimmingCharacters(in: .whitespacesAndNewlines)

        normalized = replacingLeadingPattern(#"^\d+(?:\.\d+)*\s*-\s*"#, in: normalized)
        normalized = replacingLeadingPattern(#"^\d+(?:\.\d+)*\s+"#, in: normalized)

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitLeadingLabels(from text: String) -> (labels: String, remainingText: String) {
        let separators = ["ALTERNATIV:", "ALTERNATIVE:"]
        var labels: [String] = []
        var remaining = text.trimmingCharacters(in: .whitespacesAndNewlines)

        while let separator = separators.first(where: { remaining.uppercased().hasPrefix($0) }) {
            let label = String(remaining.prefix(separator.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            labels.append(label)
            remaining = String(remaining.dropFirst(separator.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (labels.joined(separator: " "), remaining)
    }

    private func replacingLeadingPattern(_ pattern: String, in text: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private func collapseNotes(_ lines: [String]) -> String {
        lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
    }

    private var shotLineAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
    }

    private var keywordAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFontManager.shared.convert(NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), toHaveTrait: .italicFontMask),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
    }
}