import Foundation

struct ProjectPersistenceService {
    private let fileManager = FileManager.default

    func projectsDirectory() throws -> URL {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return documentsDirectory.appendingPathComponent("Lakai Projects", isDirectory: true)
    }

    func ensureBaseDirectories() throws {
        let rootURL = try projectsDirectory()
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func createProject(named title: String) throws -> (URL, ProjectDocument) {
        try ensureBaseDirectories()

        var document = ProjectDocument()
        document.title = title
        document.scriptText = ScriptSyncService().composeScript(from: document)
        document.syncOrders()

        let folderURL = try uniqueProjectFolderURL(for: title)
        try createProjectStructure(at: folderURL)
        try saveProject(document, to: folderURL)
        return (folderURL, document)
    }

    func loadProjectSummaries() throws -> [ProjectSummary] {
        try ensureBaseDirectories()
        let rootURL = try projectsDirectory()
        let folderURLs = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
            .filter { $0.hasDirectoryPath }

        return folderURLs.compactMap { folderURL in
            try? projectSummary(at: folderURL)
        }
        .sorted(by: { $0.modifiedAt > $1.modifiedAt })
    }

    func projectSummary(at folderURL: URL) throws -> ProjectSummary {
        let document = try loadProject(at: folderURL)
        let values = try folderURL.resourceValues(forKeys: [.contentModificationDateKey])

        return ProjectSummary(
            title: document.title,
            folderURL: folderURL,
            modifiedAt: values.contentModificationDate ?? document.updatedAt,
            shotCount: document.shots.count,
            storyboardVersion: document.storyboardVersion,
            scheduleVersion: document.scheduleVersion
        )
    }

    func loadProject(at folderURL: URL) throws -> ProjectDocument {
        let xmlURL = folderURL.appendingPathComponent("project.xml")
        let data = try Data(contentsOf: xmlURL)
        let xmlDocument = try XMLDocument(data: data, options: [])

        guard let root = xmlDocument.rootElement() else {
            throw CocoaError(.coderReadCorrupt)
        }

        var project = ProjectDocument()
        project.id = UUID(uuidString: root.childText(for: "id") ?? "") ?? UUID()
        project.title = root.childText(for: "title") ?? "Neues Projekt"
        project.createdAt = Self.isoDate(root.childText(for: "createdAt")) ?? Date()
        project.updatedAt = Self.isoDate(root.childText(for: "updatedAt")) ?? Date()
        project.storyboardVersion = Int(root.childText(for: "storyboardVersion") ?? "1") ?? 1
        project.scheduleVersion = Int(root.childText(for: "scheduleVersion") ?? "1") ?? 1
        project.scriptText = root.childText(for: "scriptText") ?? ""

        var legacyDefaultSetupSeconds = 15 * 60

        if let crewElement = root.firstElement(named: "crewInfo") {
            project.crewInfo = CrewInfo(
                director: crewElement.childText(for: "director") ?? "",
                firstAD: crewElement.childText(for: "firstAD") ?? "",
                producer: crewElement.childText(for: "producer") ?? "",
                client: crewElement.childText(for: "client") ?? "",
                dop: crewElement.childText(for: "dop") ?? "",
                clientLogoFileName: crewElement.childText(for: "clientLogoFileName"),
                productionLogoFileName: crewElement.childText(for: "productionLogoFileName")
            )
        }

        if let settingsElement = root.firstElement(named: "scheduleSettings") {
            legacyDefaultSetupSeconds = Int(settingsElement.childText(for: "defaultSetupSeconds") ?? "900") ?? 900
            project.scheduleSettings = ScheduleSettings(
                shootDate: Self.isoDate(settingsElement.childText(for: "shootDate")) ?? Date(),
                shootStartMinutes: Int(settingsElement.childText(for: "shootStartMinutes") ?? "480") ?? 480
            )
        }

        if let shotsElement = root.firstElement(named: "shots") {
            project.shots = shotsElement.elements(forName: "shot").map { shotElement in
                Shot(
                    id: UUID(uuidString: shotElement.attribute(forName: "id")?.stringValue ?? "") ?? UUID(),
                    size: ShotSize(rawValue: shotElement.attribute(forName: "size")?.stringValue ?? "ms") ?? .ms,
                    descriptionText: shotElement.childText(for: "descriptionText") ?? "",
                    notes: shotElement.childText(for: "notes") ?? "",
                    imageFileName: shotElement.childText(for: "imageFileName"),
                    setupSeconds: Int(shotElement.childText(for: "setupSeconds") ?? String(legacyDefaultSetupSeconds)) ?? legacyDefaultSetupSeconds,
                    durationSeconds: Int(shotElement.childText(for: "durationSeconds") ?? "1200") ?? 1200
                )
            }
        }

        project.shotOrder = root.firstElement(named: "shotOrder")?.elements(forName: "shotID").compactMap {
            UUID(uuidString: $0.stringValue ?? "")
        } ?? []

        if let scheduleBlocksElement = root.firstElement(named: "scheduleBlocks") {
            project.scheduleBlocks = scheduleBlocksElement.elements(forName: "block").map { blockElement in
                ScheduleBlock(
                    id: UUID(uuidString: blockElement.attribute(forName: "id")?.stringValue ?? "") ?? UUID(),
                    kind: ScheduleBlockKind(rawValue: blockElement.attribute(forName: "kind")?.stringValue ?? "shot") ?? .shot,
                    shotID: UUID(uuidString: blockElement.childText(for: "shotID") ?? ""),
                    title: blockElement.childText(for: "title") ?? "Pause",
                    durationSeconds: Int(blockElement.childText(for: "durationSeconds") ?? "900") ?? 900,
                    scheduleNotes: blockElement.childText(for: "scheduleNotes") ?? ""
                )
            }
        } else {
            let legacyScheduleOrder = root.firstElement(named: "scheduleOrder")?.elements(forName: "shotID").compactMap {
                UUID(uuidString: $0.stringValue ?? "")
            } ?? []

            project.scheduleBlocks = legacyScheduleOrder.map {
                ScheduleBlock(kind: .shot, shotID: $0, title: "", durationSeconds: 0, scheduleNotes: "")
            }
        }

        project.syncOrders()
        if project.scriptText.isEmpty {
            project.scriptText = ScriptSyncService().composeScript(from: project)
        }
        return project
    }

    func renameProjectFolderIfNeeded(currentFolderURL: URL, projectTitle: String) throws -> URL {
        let sanitizedTitle = projectTitle.fileNameSafe.isEmpty ? "Lakai Project" : projectTitle.fileNameSafe
        let targetURL = currentFolderURL.deletingLastPathComponent().appendingPathComponent(sanitizedTitle, isDirectory: true)

        guard currentFolderURL.lastPathComponent != sanitizedTitle else {
            return currentFolderURL
        }

        let resolvedTargetURL = uniqueSiblingURL(startingWith: targetURL, excluding: currentFolderURL)
        try fileManager.moveItem(at: currentFolderURL, to: resolvedTargetURL)
        return resolvedTargetURL
    }

    func saveProject(_ project: ProjectDocument, to folderURL: URL) throws {
        try createProjectStructure(at: folderURL)

        let root = XMLElement(name: "lakaiProject")
        root.addChild(XMLElement(name: "id", stringValue: project.id.uuidString))
        root.addChild(XMLElement(name: "title", stringValue: project.title))
        root.addChild(XMLElement(name: "createdAt", stringValue: Self.isoFormatter.string(from: project.createdAt)))
        root.addChild(XMLElement(name: "updatedAt", stringValue: Self.isoFormatter.string(from: project.updatedAt)))
        root.addChild(XMLElement(name: "storyboardVersion", stringValue: String(project.storyboardVersion)))
        root.addChild(XMLElement(name: "scheduleVersion", stringValue: String(project.scheduleVersion)))
        root.addChild(XMLElement(name: "scriptText", stringValue: project.scriptText))

        let crewInfo = XMLElement(name: "crewInfo")
        crewInfo.addChild(XMLElement(name: "director", stringValue: project.crewInfo.director))
        crewInfo.addChild(XMLElement(name: "firstAD", stringValue: project.crewInfo.firstAD))
        crewInfo.addChild(XMLElement(name: "producer", stringValue: project.crewInfo.producer))
        crewInfo.addChild(XMLElement(name: "client", stringValue: project.crewInfo.client))
        crewInfo.addChild(XMLElement(name: "dop", stringValue: project.crewInfo.dop))
        crewInfo.addChild(XMLElement(name: "clientLogoFileName", stringValue: project.crewInfo.clientLogoFileName))
        crewInfo.addChild(XMLElement(name: "productionLogoFileName", stringValue: project.crewInfo.productionLogoFileName))
        root.addChild(crewInfo)

        let scheduleSettings = XMLElement(name: "scheduleSettings")
        scheduleSettings.addChild(XMLElement(name: "shootDate", stringValue: Self.isoFormatter.string(from: project.scheduleSettings.shootDate)))
        scheduleSettings.addChild(XMLElement(name: "shootStartMinutes", stringValue: String(project.scheduleSettings.shootStartMinutes)))
        root.addChild(scheduleSettings)

        let shots = XMLElement(name: "shots")
        for shot in project.shots {
            let shotElement = XMLElement(name: "shot")
            if let idAttribute = XMLNode.attribute(withName: "id", stringValue: shot.id.uuidString) as? XMLNode {
                shotElement.addAttribute(idAttribute)
            }
            if let sizeAttribute = XMLNode.attribute(withName: "size", stringValue: shot.size.rawValue) as? XMLNode {
                shotElement.addAttribute(sizeAttribute)
            }
            shotElement.addChild(XMLElement(name: "descriptionText", stringValue: shot.descriptionText))
            shotElement.addChild(XMLElement(name: "notes", stringValue: shot.notes))
            shotElement.addChild(XMLElement(name: "imageFileName", stringValue: shot.imageFileName))
            shotElement.addChild(XMLElement(name: "setupSeconds", stringValue: String(shot.setupSeconds)))
            shotElement.addChild(XMLElement(name: "durationSeconds", stringValue: String(shot.durationSeconds)))
            shots.addChild(shotElement)
        }
        root.addChild(shots)

        let shotOrder = XMLElement(name: "shotOrder")
        project.shotOrder.forEach { shotOrder.addChild(XMLElement(name: "shotID", stringValue: $0.uuidString)) }
        root.addChild(shotOrder)

        let scheduleBlocks = XMLElement(name: "scheduleBlocks")
        for block in project.scheduleBlocks {
            let blockElement = XMLElement(name: "block")
            if let idAttribute = XMLNode.attribute(withName: "id", stringValue: block.id.uuidString) as? XMLNode {
                blockElement.addAttribute(idAttribute)
            }
            if let kindAttribute = XMLNode.attribute(withName: "kind", stringValue: block.kind.rawValue) as? XMLNode {
                blockElement.addAttribute(kindAttribute)
            }
            blockElement.addChild(XMLElement(name: "shotID", stringValue: block.shotID?.uuidString))
            blockElement.addChild(XMLElement(name: "title", stringValue: block.title))
            blockElement.addChild(XMLElement(name: "durationSeconds", stringValue: String(block.durationSeconds)))
            blockElement.addChild(XMLElement(name: "scheduleNotes", stringValue: block.scheduleNotes))
            scheduleBlocks.addChild(blockElement)
        }
        root.addChild(scheduleBlocks)

        let xml = XMLDocument(rootElement: root)
        xml.characterEncoding = "utf-8"
        xml.version = "1.0"
        xml.isStandalone = true
        xml.documentContentKind = .xml

        let xmlData = xml.xmlData(options: [.nodePrettyPrint])
        try xmlData.write(to: folderURL.appendingPathComponent("project.xml"), options: .atomic)
    }

    func copyAsset(from sourceURL: URL, toProjectFolder folderURL: URL, subfolder: String) throws -> String {
        let targetDirectory = folderURL.appendingPathComponent(subfolder, isDirectory: true)
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let baseName = sourceURL.deletingPathExtension().lastPathComponent.fileNameSafe
        let fileExtension = sourceURL.pathExtension
        var fileName = "\(baseName).\(fileExtension)"
        var destinationURL = targetDirectory.appendingPathComponent(fileName)
        var index = 2

        while fileManager.fileExists(atPath: destinationURL.path) {
            fileName = "\(baseName)-\(index).\(fileExtension)"
            destinationURL = targetDirectory.appendingPathComponent(fileName)
            index += 1
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return fileName
    }

    func resolveAssetURL(fileName: String?, in folderURL: URL, subfolder: String) -> URL? {
        guard let fileName, !fileName.isEmpty else {
            return nil
        }

        let assetURL = folderURL.appendingPathComponent(subfolder).appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: assetURL.path) ? assetURL : nil
    }

    private func uniqueProjectFolderURL(for title: String) throws -> URL {
        let rootURL = try projectsDirectory()
        let cleanedTitle = title.fileNameSafe.isEmpty ? "Lakai Project" : title.fileNameSafe
        var folderURL = rootURL.appendingPathComponent(cleanedTitle, isDirectory: true)
        var index = 2

        while fileManager.fileExists(atPath: folderURL.path) {
            folderURL = rootURL.appendingPathComponent("\(cleanedTitle) \(index)", isDirectory: true)
            index += 1
        }

        return folderURL
    }

    private func uniqueSiblingURL(startingWith targetURL: URL, excluding currentURL: URL) -> URL {
        var candidateURL = targetURL
        var index = 2

        while candidateURL != currentURL && fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = targetURL.deletingLastPathComponent().appendingPathComponent("\(targetURL.lastPathComponent) \(index)", isDirectory: true)
            index += 1
        }

        return candidateURL
    }

    private func createProjectStructure(at folderURL: URL) throws {
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: folderURL.appendingPathComponent("Images", isDirectory: true), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: folderURL.appendingPathComponent("Logos", isDirectory: true), withIntermediateDirectories: true)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func isoDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        return isoFormatter.date(from: value)
    }
}

private extension XMLElement {
    func childText(for name: String) -> String? {
        firstElement(named: name)?.stringValue
    }

    func firstElement(named name: String) -> XMLElement? {
        elements(forName: name).first
    }
}