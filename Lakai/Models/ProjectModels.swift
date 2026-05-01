import Foundation

// WorkspaceMode drives the slider-style switch between storyboard editing and schedule planning.
enum WorkspaceMode: String, CaseIterable, Identifiable {
    case script
    case shotlist
    case schedule

    var id: String { rawValue }

    var title: String {
        switch self {
        case .script:
            return "Skript"
        case .shotlist:
            return "Storyboard"
        case .schedule:
            return "Drehplan"
        }
    }
}

// ShotSize is intentionally compact in storage and explicit in the UI.
enum ShotSize: String, CaseIterable, Identifiable, Codable {
    case ecu
    case cu
    case mcu
    case ms
    case mls
    case ls
    case xls

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ecu:
            return "Extremdetail"
        case .cu:
            return "Detail"
        case .mcu:
            return "Nahaufnahme"
        case .ms:
            return "Halbnah"
        case .mls:
            return "Amerikanisch"
        case .ls:
            return "Halbtotale"
        case .xls:
            return "Totale"
        }
    }

    var description: String {
        switch self {
        case .ecu:
            return "Extremdetail"
        case .cu:
            return "Detail"
        case .mcu:
            return "Nahaufnahme"
        case .ms:
            return "Halbnah"
        case .mls:
            return "Amerikanisch"
        case .ls:
            return "Halbtotale"
        case .xls:
            return "Totale"
        }
    }

    var scriptKeyword: String {
        switch self {
        case .ecu:
            return "Extreme Close"
        case .cu:
            return "Close Up"
        case .mcu:
            return "Medium Close"
        case .ms:
            return "Medium Shot"
        case .mls:
            return "Medium Wide"
        case .ls:
            return "Wide Shot"
        case .xls:
            return "Totale"
        }
    }

    static var scriptKeywordMatchers: [(String, ShotSize)] {
        [
            ("extreme close", .ecu),
            ("close up", .cu),
            ("close-up", .cu),
            ("close", .cu),
            ("medium close", .mcu),
            ("medium shot", .ms),
            ("medium wide", .mls),
            ("wide shot", .ls),
            ("wide", .ls),
            ("halbnah", .ms),
            ("nahaufnahme", .mcu),
            ("nah", .mcu),
            ("totale", .xls)
        ]
    }
}

enum LogoKind {
    case client
    case production

    var title: String {
        switch self {
        case .client:
            return "Kundenlogo"
        case .production:
            return "Produktionslogo"
        }
    }

    var folderName: String {
        "Logos"
    }
}

enum ScheduleBlockKind: String, Codable, Hashable {
    case shot
    case pause
    case dayHeader
}

enum ShotlistItemKind: String, Codable, Hashable {
    case shot
    case sceneDivider
}

struct ShotlistItemRef: Codable, Hashable {
    var kind: ShotlistItemKind
    var id: UUID
}

struct SceneDivider: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
}

struct CastMember: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = ""
    var dayBlockID: UUID? = nil
    var showInAllDays: Bool = false
}

struct ProjectSummary: Identifiable, Hashable {
    let title: String
    let folderURL: URL
    let modifiedAt: Date
    let shotCount: Int
    let storyboardVersion: Int
    let scheduleVersion: Int

    var id: String {
        folderURL.path
    }
}

struct CrewInfo: Codable, Hashable {
    var director: String = ""
    var firstAD: String = ""
    var producer: String = ""
    var client: String = ""
    var dop: String = ""
    var clientLogoFileName: String?
    var productionLogoFileName: String?
}

struct ScheduleSettings: Codable, Hashable {
    var shootDate: Date = Date()
    var shootStartMinutes: Int = 8 * 60
    var setupTitle: String = "Setup"
    var setupDurationSeconds: Int = 15 * 60
}

struct Shot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var size: ShotSize = .ms
    var descriptionText: String = ""
    var notes: String = ""
    var imageFileName: String?
    var setupSeconds: Int = 15 * 60
    var durationSeconds: Int = 20 * 60
    var isOptional: Bool = false
    var backgroundColor: String? = nil
    var castMemberIDs: [UUID] = []
    var autoMatchedCastIDs: [UUID] = []
    var location: String = ""
    var props: String = ""
}

struct ScheduleBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: ScheduleBlockKind = .shot
    var shotID: UUID?
    var title: String = "Pause"
    var durationSeconds: Int = 15 * 60
    var scheduleNotes: String = ""
    var backgroundColor: String? = nil
    // Day header fields — only used when kind == .dayHeader
    var date: Date? = nil
    var dayStartMinutes: Int = 8 * 60
    var daySetupDurationSeconds: Int = 15 * 60
    var isBUnit: Bool = false
}

struct ProjectDocument: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String = "Neues Projekt"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var storyboardVersion: Int = 1
    var scheduleVersion: Int = 1
    var shots: [Shot] = []
    var shotOrder: [UUID] = []
    var sceneDividers: [SceneDivider] = []
    var shotlistItemOrder: [ShotlistItemRef] = []
    var scheduleBlocks: [ScheduleBlock] = []
    var scriptText: String = ""
    var crewInfo: CrewInfo = CrewInfo()
    var scheduleSettings: ScheduleSettings = ScheduleSettings()
    var castMembers: [CastMember] = []

    var orderedShots: [Shot] {
        let lookup = Dictionary(uniqueKeysWithValues: shots.map { ($0.id, $0) })
        return shotOrder.compactMap { lookup[$0] }
    }

    var orderedScheduleBlocks: [ScheduleBlock] {
        let validIDs = Set(shots.map(\.id))
        return scheduleBlocks.filter { block in
            switch block.kind {
            case .pause, .dayHeader:
                return true
            case .shot:
                guard let shotID = block.shotID else {
                    return false
                }

                return validIDs.contains(shotID)
            }
        }
    }

    func shot(with id: UUID) -> Shot? {
        shots.first(where: { $0.id == id })
    }

    func scheduleBlock(with id: UUID) -> ScheduleBlock? {
        scheduleBlocks.first(where: { $0.id == id })
    }

    func shotNumber(for id: UUID) -> Int {
        guard let index = shotOrder.firstIndex(of: id) else {
            return 0
        }

        return index + 1
    }

    func displayShotNumber(for id: UUID) -> String {
        guard let shot = shot(with: id) else { return "?" }

        // Find this shot's position in the mixed shotlist order
        guard let shotRefIndex = shotlistItemOrder.firstIndex(where: { $0.kind == .shot && $0.id == id }) else {
            return "?"
        }

        let hasDividers = shotlistItemOrder.contains(where: { $0.kind == .sceneDivider })

        // Start of current scene: index after the last divider before this shot, or 0
        let sceneStartIndex: Int
        if let lastDividerIndex = shotlistItemOrder.prefix(shotRefIndex).lastIndex(where: { $0.kind == .sceneDivider }) {
            sceneStartIndex = lastDividerIndex + 1
        } else {
            sceneStartIndex = 0
        }

        // Unified counter: all shots (optional and non-optional) share one position sequence.
        let sceneRange = shotlistItemOrder[sceneStartIndex...shotRefIndex]
        let pos = sceneRange.filter { $0.kind == .shot }.count

        let optSuffix = shot.isOptional ? "(opt)" : ""

        if hasDividers {
            let sceneNumber = shotlistItemOrder.prefix(shotRefIndex).filter { $0.kind == .sceneDivider }.count
            return "\(sceneNumber)-\(pos)\(optSuffix)"
        } else {
            return "\(pos)\(optSuffix)"
        }
    }

    func sceneDivider(with id: UUID) -> SceneDivider? {
        sceneDividers.first(where: { $0.id == id })
    }

    // Returns the scene number (0-based count of preceding dividers) for a given shotlist item index.
    func sceneNumber(atItemIndex index: Int) -> Int {
        guard index >= 0 && index < shotlistItemOrder.count else { return 1 }
        return shotlistItemOrder.prefix(index).filter { $0.kind == .sceneDivider }.count + 1
    }

    mutating func syncOrders() {
        let validShotIDs = Set(shots.map(\.id))
        let validDividerIDs = Set(sceneDividers.map(\.id))

        // Clean up shotlistItemOrder: remove refs for non-existent items.
        shotlistItemOrder.removeAll { ref in
            switch ref.kind {
            case .shot: return !validShotIDs.contains(ref.id)
            case .sceneDivider: return !validDividerIDs.contains(ref.id)
            }
        }

        // Add any shots not yet referenced in shotlistItemOrder.
        // Respect shotOrder for relative ordering of new entries.
        let existingOrderedShotIDs = Set(shotlistItemOrder.compactMap { $0.kind == .shot ? $0.id : nil })
        let newShotIDs = shotOrder.filter { !existingOrderedShotIDs.contains($0) }
        for id in newShotIDs {
            shotlistItemOrder.append(ShotlistItemRef(kind: .shot, id: id))
        }

        // Derive shotOrder from shotlistItemOrder so schedule code stays consistent.
        shotOrder = shotlistItemOrder.compactMap { $0.kind == .shot ? $0.id : nil }

        // Schedule cleanup.
        scheduleBlocks.removeAll { block in
            guard block.kind == .shot else { return false }
            guard let shotID = block.shotID else { return true }
            return !validShotIDs.contains(shotID)
        }

        let scheduledShotIDs = Set(scheduleBlocks.compactMap(\.shotID))
        for shotID in shotOrder where !scheduledShotIDs.contains(shotID) {
            scheduleBlocks.append(
                ScheduleBlock(
                    kind: .shot,
                    shotID: shotID,
                    title: "",
                    durationSeconds: 0,
                    scheduleNotes: ""
                )
            )
        }
    }

    mutating func addShot() {
        let shot = Shot()
        shots.append(shot)
        shotOrder.append(shot.id)
        shotlistItemOrder.append(ShotlistItemRef(kind: .shot, id: shot.id))
        scheduleBlocks.append(
            ScheduleBlock(
                kind: .shot,
                shotID: shot.id,
                title: "",
                durationSeconds: 0,
                scheduleNotes: ""
            )
        )
        autoMatchNewShot(shot.id)
    }

    mutating func autoMatchNewCastMember(_ member: CastMember) {
        let memberName = member.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Auto-match by name: fire once per shot where name appears in description.
        guard !memberName.isEmpty else { return }
        for i in shots.indices {
            guard !shots[i].autoMatchedCastIDs.contains(member.id) else { continue }
            if shots[i].descriptionText.lowercased().contains(memberName) {
                if !shots[i].castMemberIDs.contains(member.id) {
                    shots[i].castMemberIDs.append(member.id)
                }
                shots[i].autoMatchedCastIDs.append(member.id)
            }
        }
    }

    mutating func autoMatchNewShot(_ shotID: UUID) {
        guard let shotIndex = shots.firstIndex(where: { $0.id == shotID }) else { return }
        let descLower = shots[shotIndex].descriptionText.lowercased()
        for member in castMembers {
            // Auto-match by name.
            let memberName = member.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !memberName.isEmpty else { continue }
            guard !shots[shotIndex].autoMatchedCastIDs.contains(member.id) else { continue }
            if descLower.contains(memberName) {
                if !shots[shotIndex].castMemberIDs.contains(member.id) {
                    shots[shotIndex].castMemberIDs.append(member.id)
                }
                shots[shotIndex].autoMatchedCastIDs.append(member.id)
            }
        }
    }

    mutating func addSceneDivider() {
        let divider = SceneDivider()
        sceneDividers.append(divider)
        let existingDividerCount = shotlistItemOrder.filter { $0.kind == .sceneDivider }.count
        if existingDividerCount == 0 {
            // First divider goes to the very top of the list.
            shotlistItemOrder.insert(ShotlistItemRef(kind: .sceneDivider, id: divider.id), at: 0)
        } else {
            // Subsequent dividers are appended at the end.
            shotlistItemOrder.append(ShotlistItemRef(kind: .sceneDivider, id: divider.id))
        }
    }

    mutating func removeSceneDivider(id: UUID) {
        sceneDividers.removeAll(where: { $0.id == id })
        shotlistItemOrder.removeAll(where: { $0.kind == .sceneDivider && $0.id == id })
    }

    mutating func updateSceneDivider(id: UUID, title: String) {
        guard let index = sceneDividers.firstIndex(where: { $0.id == id }) else { return }
        sceneDividers[index].title = title
    }

    mutating func addPauseBlock(title: String = "Pause") {
        scheduleBlocks.append(
            ScheduleBlock(
                kind: .pause,
                shotID: nil,
                title: title,
                durationSeconds: 15 * 60,
                scheduleNotes: ""
            )
        )
    }

    mutating func addDayBlock() {
        // Default to one day after the shoot date (or one day after the last existing day header)
        let existingDayDates: [Date] = scheduleBlocks
            .filter { $0.kind == .dayHeader }
            .compactMap { $0.date }
        let allDates = [scheduleSettings.shootDate] + existingDayDates
        let latestDate = allDates.max() ?? scheduleSettings.shootDate
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: latestDate) ?? latestDate

        // Auto-detect B-Unit: same calendar day as any existing shoot day
        let isBUnit = allDates.contains { Calendar.current.isDate($0, inSameDayAs: nextDay) }

        scheduleBlocks.append(ScheduleBlock(
            kind: .dayHeader,
            shotID: nil,
            title: "",
            durationSeconds: 0,
            scheduleNotes: "",
            backgroundColor: nil,
            date: nextDay,
            dayStartMinutes: 8 * 60,
            isBUnit: isBUnit
        ))
    }

    mutating func updateShot(id: UUID, _ mutate: (inout Shot) -> Void) {
        guard let index = shots.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&shots[index])
    }

    mutating func deleteShot(id: UUID) {
        shots.removeAll(where: { $0.id == id })
        shotOrder.removeAll(where: { $0 == id })
        shotlistItemOrder.removeAll(where: { $0.kind == .shot && $0.id == id })
        scheduleBlocks.removeAll(where: { $0.shotID == id })
    }

    mutating func deleteScheduleBlock(id: UUID) {
        scheduleBlocks.removeAll { $0.id == id && ($0.kind == .pause || $0.kind == .dayHeader) }
    }

    mutating func updateScheduleBlock(id: UUID, _ mutate: (inout ScheduleBlock) -> Void) {
        guard let index = scheduleBlocks.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&scheduleBlocks[index])
    }

    mutating func moveItem(from sourceIndex: Int, to destinationIndex: Int, in mode: WorkspaceMode) {
        switch mode {
        case .script:
            return
        case .shotlist:
            guard shotlistItemOrder.indices.contains(sourceIndex) else {
                return
            }

            let targetIndex = max(0, min(destinationIndex, shotlistItemOrder.count))
            let insertionIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
            let item = shotlistItemOrder.remove(at: sourceIndex)
            shotlistItemOrder.insert(item, at: max(0, min(insertionIndex, shotlistItemOrder.count)))
        case .schedule:
            guard scheduleBlocks.indices.contains(sourceIndex) else {
                return
            }

            let targetIndex = max(0, min(destinationIndex, scheduleBlocks.count))
            let insertionIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
            let item = scheduleBlocks.remove(at: sourceIndex)
            scheduleBlocks.insert(item, at: max(0, min(insertionIndex, scheduleBlocks.count)))
        }
    }

    /// Move a group of selected items (keeping relative order) to just after `anchorID`.
    mutating func moveMultipleItems(in mode: WorkspaceMode, draggedID: UUID, selectedIDs: Set<UUID>, anchorID: UUID) {
        switch mode {
        case .script:
            return
        case .shotlist:
            // Extract selected items in current order, remove them from the list.
            let group = shotlistItemOrder.filter { selectedIDs.contains($0.id) }
            shotlistItemOrder.removeAll { selectedIDs.contains($0.id) }
            // Find insertion point (after anchorID, which is now in the pruned list).
            if let anchorIdx = shotlistItemOrder.firstIndex(where: { $0.id == anchorID }) {
                shotlistItemOrder.insert(contentsOf: group, at: anchorIdx + 1)
            } else {
                // Anchor was part of the group or not found — append at end.
                shotlistItemOrder.append(contentsOf: group)
            }
        case .schedule:
            let group = scheduleBlocks.filter { selectedIDs.contains($0.id) }
            scheduleBlocks.removeAll { selectedIDs.contains($0.id) }
            if let anchorIdx = scheduleBlocks.firstIndex(where: { $0.id == anchorID }) {
                scheduleBlocks.insert(contentsOf: group, at: anchorIdx + 1)
            } else {
                scheduleBlocks.append(contentsOf: group)
            }
        }
    }
}

struct CalculatedScheduleEntry: Identifiable, Hashable {
    let block: ScheduleBlock
    let shot: Shot?
    let shotNumber: Int?
    let setupStart: Int?
    let startTime: Int
    let endTime: Int
    let nextAvailable: Int

    var id: UUID {
        block.id
    }
}

struct ScheduleComputation: Hashable {
    let entries: [CalculatedScheduleEntry]
}