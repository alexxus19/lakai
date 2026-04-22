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
            return "Shotlist"
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
}

struct ScheduleBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: ScheduleBlockKind = .shot
    var shotID: UUID?
    var title: String = "Pause"
    var durationSeconds: Int = 15 * 60
    var scheduleNotes: String = ""
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
    var scheduleBlocks: [ScheduleBlock] = []
    var scriptText: String = ""
    var crewInfo: CrewInfo = CrewInfo()
    var scheduleSettings: ScheduleSettings = ScheduleSettings()

    var orderedShots: [Shot] {
        let lookup = Dictionary(uniqueKeysWithValues: shots.map { ($0.id, $0) })
        return shotOrder.compactMap { lookup[$0] }
    }

    var orderedScheduleBlocks: [ScheduleBlock] {
        let validIDs = Set(shots.map(\.id))
        return scheduleBlocks.filter { block in
            switch block.kind {
            case .pause:
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

    mutating func syncOrders() {
        let validIDs = Set(shots.map(\.id))

        shotOrder.removeAll(where: { !validIDs.contains($0) })

        for shot in shots where !shotOrder.contains(shot.id) {
            shotOrder.append(shot.id)
        }

        scheduleBlocks.removeAll { block in
            guard block.kind == .shot else {
                return false
            }

            guard let shotID = block.shotID else {
                return true
            }

            return !validIDs.contains(shotID)
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
        scheduleBlocks.append(
            ScheduleBlock(
                kind: .shot,
                shotID: shot.id,
                title: "",
                durationSeconds: 0,
                scheduleNotes: ""
            )
        )
    }

    mutating func addPauseBlock() {
        scheduleBlocks.append(
            ScheduleBlock(
                kind: .pause,
                shotID: nil,
                title: "Pause",
                durationSeconds: 15 * 60,
                scheduleNotes: ""
            )
        )
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
        scheduleBlocks.removeAll(where: { $0.shotID == id })
    }

    mutating func deleteScheduleBlock(id: UUID) {
        scheduleBlocks.removeAll { $0.id == id && $0.kind == .pause }
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
            guard shotOrder.indices.contains(sourceIndex) else {
                return
            }

            let targetIndex = max(0, min(destinationIndex, shotOrder.count))
            let insertionIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
            let item = shotOrder.remove(at: sourceIndex)
            shotOrder.insert(item, at: max(0, min(insertionIndex, shotOrder.count)))
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