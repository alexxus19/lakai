import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var projectSummaries: [ProjectSummary] = []
    @Published var activeProject: ProjectDocument?
    @Published var currentMode: WorkspaceMode = .shotlist
    @Published var errorMessage: String?

    private(set) var activeProjectURL: URL?

    private let persistence = ProjectPersistenceService()
    private let packaging = ProjectPackagingService()
    private let pdfExporter = PDFExportService()
    private let scheduleCalculator = ScheduleCalculator()
    private let scriptSync = ScriptSyncService()
    private var hasPendingReorderChanges = false
    private var pendingReorderMode: WorkspaceMode?
    private let lakArchiveType = UTType("com.lakai.archive") ?? .zip

    init() {
        refreshLibrary()
    }

    func refreshLibrary() {
        do {
            try persistence.ensureBaseDirectories()
            projectSummaries = try persistence.loadProjectSummaries()
        } catch {
            presentError(error)
        }
    }

    func createProject() {
        do {
            let (folderURL, project) = try persistence.createProject(named: "Neues Projekt")
            withAnimation(.snappy(duration: 0.35, extraBounce: 0.08)) {
                activeProjectURL = folderURL
                activeProject = project
                currentMode = .shotlist
            }
            refreshLibrary()
        } catch {
            presentError(error)
        }
    }

    func openProject(_ summary: ProjectSummary) {
        do {
            let project = try persistence.loadProject(at: summary.folderURL)
            withAnimation(.snappy(duration: 0.35, extraBounce: 0.06)) {
                activeProject = project
                activeProjectURL = summary.folderURL
                currentMode = .shotlist
            }
        } catch {
            presentError(error)
        }
    }

    func closeProject() {
        withAnimation(.snappy(duration: 0.32, extraBounce: 0.02)) {
            activeProject = nil
            activeProjectURL = nil
            currentMode = .shotlist
        }
        refreshLibrary()
    }

    func updateProjectTitle(_ title: String) {
        mutateProject { project in
            project.title = title.isEmpty ? "Neues Projekt" : title
        }
    }

    func updateScriptText(_ text: String) {
        mutateProject(syncScriptFromShots: false) { project in
            let syncResult = scriptSync.parseScript(text, preserving: project)
            project.scriptText = syncResult.scriptText
            project.shots = syncResult.shots
            project.shotOrder = syncResult.shotOrder
            project.scheduleBlocks = syncResult.scheduleBlocks
        }
    }

    func addShot() {
        mutateProject(animated: true) { project in
            project.addShot()
        }
    }

    func addPauseBlock() {
        mutateProject(animated: true) { project in
            project.addPauseBlock()
        }
    }

    func deleteShot(_ id: UUID) {
        mutateProject(animated: true) { project in
            project.deleteShot(id: id)
        }
    }

    func deleteScheduleBlock(_ id: UUID) {
        mutateProject(animated: true) { project in
            project.deleteScheduleBlock(id: id)
        }
    }

    func moveItem(in mode: WorkspaceMode, from sourceIndex: Int, to destinationIndex: Int) {
        mutateProject(animated: true, syncScriptFromShots: mode == .shotlist) { project in
            project.moveItem(from: sourceIndex, to: destinationIndex, in: mode)
        }
    }

    func moveItemLive(in mode: WorkspaceMode, from sourceIndex: Int, to destinationIndex: Int) {
        guard var project = activeProject else {
            return
        }

        project.moveItem(from: sourceIndex, to: destinationIndex, in: mode)

        activeProject = project
        hasPendingReorderChanges = true
        pendingReorderMode = mode
    }

    func commitPendingReorderChanges() {
        guard hasPendingReorderChanges else {
            return
        }

        guard var project = activeProject,
              let activeProjectURL else {
            hasPendingReorderChanges = false
            pendingReorderMode = nil
            return
        }

        if pendingReorderMode == .shotlist {
            project.scriptText = scriptSync.composeScript(from: project)
        }

        project.updatedAt = Date()
        project.syncOrders()

        do {
            let resolvedProjectURL = try persistence.renameProjectFolderIfNeeded(currentFolderURL: activeProjectURL, projectTitle: project.title)
            try persistence.saveProject(project, to: resolvedProjectURL)
            self.activeProjectURL = resolvedProjectURL
            activeProject = project
            refreshLibrary()
            hasPendingReorderChanges = false
            pendingReorderMode = nil
        } catch {
            presentError(error)
        }
    }

    func updateShotSize(_ id: UUID, size: ShotSize) {
        mutateProject { project in
            project.updateShot(id: id) { $0.size = size }
        }
    }

    func updateShotDescription(_ id: UUID, text: String) {
        mutateProject { project in
            project.updateShot(id: id) { $0.descriptionText = text }
        }
    }

    func updateShotNotes(_ id: UUID, text: String) {
        mutateProject { project in
            project.updateShot(id: id) { $0.notes = text }
        }
    }

    func updateShotDuration(_ id: UUID, text: String) {
        guard let seconds = LakaiFormatters.parseDuration(text) else {
            return
        }

        mutateProject { project in
            project.updateShot(id: id) { $0.durationSeconds = seconds }
        }
    }

    func updateShotSetup(_ id: UUID, text: String) {
        guard let seconds = LakaiFormatters.parseDuration(text) else {
            return
        }

        mutateProject { project in
            project.updateShot(id: id) { $0.setupSeconds = seconds }
        }
    }

    func updatePauseTitle(_ id: UUID, text: String) {
        mutateProject { project in
            project.updateScheduleBlock(id: id) { $0.title = text }
        }
    }

    func updatePauseDuration(_ id: UUID, text: String) {
        guard let seconds = LakaiFormatters.parseDuration(text) else {
            return
        }

        mutateProject { project in
            project.updateScheduleBlock(id: id) { $0.durationSeconds = seconds }
        }
    }

    func updateScheduleNotes(_ id: UUID, text: String) {
        mutateProject(syncScriptFromShots: false) { project in
            project.updateScheduleBlock(id: id) { $0.scheduleNotes = text }
        }
    }

    func clearShotImage(_ id: UUID) {
        mutateProject { project in
            project.updateShot(id: id) { $0.imageFileName = nil }
        }
    }

    func importShotImage(for id: UUID) {
        guard let activeProjectURL, let pickedURL = pickFile(allowedTypes: [.image]) else {
            return
        }

        do {
            let fileName = try persistence.copyAsset(from: pickedURL, toProjectFolder: activeProjectURL, subfolder: "Images")
            mutateProject { project in
                project.updateShot(id: id) { $0.imageFileName = fileName }
            }
        } catch {
            presentError(error)
        }
    }

    func importLogo(_ kind: LogoKind) {
        guard let activeProjectURL, let pickedURL = pickFile(allowedTypes: [.image]) else {
            return
        }

        do {
            let fileName = try persistence.copyAsset(from: pickedURL, toProjectFolder: activeProjectURL, subfolder: kind.folderName)
            mutateProject { project in
                switch kind {
                case .client:
                    project.crewInfo.clientLogoFileName = fileName
                case .production:
                    project.crewInfo.productionLogoFileName = fileName
                }
            }
        } catch {
            presentError(error)
        }
    }

    func clearLogo(_ kind: LogoKind) {
        mutateProject { project in
            switch kind {
            case .client:
                project.crewInfo.clientLogoFileName = nil
            case .production:
                project.crewInfo.productionLogoFileName = nil
            }
        }
    }

    func updateCrewValue(_ value: String, at keyPath: WritableKeyPath<CrewInfo, String>) {
        mutateProject { project in
            project.crewInfo[keyPath: keyPath] = value
        }
    }

    func switchMode(_ mode: WorkspaceMode) {
        withAnimation(.snappy(duration: 0.28, extraBounce: 0.02)) {
            currentMode = mode
        }
    }

    func updateShootDate(_ date: Date) {
        mutateProject { project in
            project.scheduleSettings.shootDate = date
        }
    }

    func updateShootStart(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 8) * 60 + (components.minute ?? 0)

        mutateProject { project in
            project.scheduleSettings.shootStartMinutes = minutes
        }
    }

    func updateSetupTitle(_ title: String) {
        mutateProject { project in
            project.scheduleSettings.setupTitle = title
        }
    }

    func updateSetupDuration(_ text: String) {
        guard let seconds = LakaiFormatters.parseDuration(text) else {
            return
        }

        mutateProject { project in
            project.scheduleSettings.setupDurationSeconds = seconds
        }
    }

    func exportStoryboardPDF() {
        guard let activeProject else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(activeProject.title.fileNameSafe)-Storyboard-v\(activeProject.storyboardVersion).pdf"

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            _ = try pdfExporter.exportStoryboard(project: activeProject, destinationURL: destinationURL, activeProjectURL: activeProjectURL, persistence: persistence)
            mutateProject { project in
                project.storyboardVersion += 1
            }
        } catch {
            presentError(error)
        }
    }

    func exportSchedulePDF() {
        guard let activeProject else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(activeProject.title.fileNameSafe)-Drehplan-v\(activeProject.scheduleVersion).pdf"

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            let computation = scheduleCalculator.buildComputation(for: activeProject)
            _ = try pdfExporter.exportSchedule(project: activeProject, computation: computation, destinationURL: destinationURL, activeProjectURL: activeProjectURL, persistence: persistence)
            mutateProject { project in
                project.scheduleVersion += 1
            }
        } catch {
            presentError(error)
        }
    }

    func exportProjectArchive() {
        guard let activeProject, let activeProjectURL else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [lakArchiveType]
        panel.nameFieldStringValue = "\(activeProject.title.fileNameSafe).lak"

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            try packaging.exportProjectFolder(at: activeProjectURL, to: destinationURL)
        } catch {
            presentError(error)
        }
    }

    func importProjectArchive() {
        guard let archiveURL = pickFile(allowedTypes: [lakArchiveType]) else {
            return
        }

        do {
            let destinationFolder = try packaging.importProjectArchive(at: archiveURL, projectsDirectory: try persistence.projectsDirectory())
            refreshLibrary()
            let summary = try persistence.projectSummary(at: destinationFolder)
            openProject(summary)
        } catch {
            presentError(error)
        }
    }

    func deleteProject(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            refreshLibrary()
        } catch {
            presentError(error)
        }
    }

    func imageURL(for shot: Shot) -> URL? {
        guard let activeProjectURL else {
            return nil
        }

        return persistence.resolveAssetURL(fileName: shot.imageFileName, in: activeProjectURL, subfolder: "Images")
    }

    func logoURL(for kind: LogoKind) -> URL? {
        guard let activeProject, let activeProjectURL else {
            return nil
        }

        let fileName: String?

        switch kind {
        case .client:
            fileName = activeProject.crewInfo.clientLogoFileName
        case .production:
            fileName = activeProject.crewInfo.productionLogoFileName
        }

        return persistence.resolveAssetURL(fileName: fileName, in: activeProjectURL, subfolder: kind.folderName)
    }

    func scheduleComputation() -> ScheduleComputation? {
        guard let activeProject else {
            return nil
        }

        return scheduleCalculator.buildComputation(for: activeProject)
    }

    func toggleShotOptional(_ id: UUID) {
        mutateProject { project in
            project.updateShot(id: id) { $0.isOptional.toggle() }
        }
    }

    func setShotBackgroundColor(_ id: UUID, color: String?) {
        mutateProject { project in
            project.updateShot(id: id) { $0.backgroundColor = color }
        }
    }

    func setScheduleBlockBackgroundColor(_ id: UUID, color: String?) {
        mutateProject { project in
            project.updateScheduleBlock(id: id) { $0.backgroundColor = color }
        }
    }

    func duplicateShot(_ id: UUID) {
        mutateProject(animated: true) { project in
            guard let sourceShot = project.shot(with: id),
                  let sourceIndex = project.shotOrder.firstIndex(of: id) else {
                return
            }

            var newShot = sourceShot
            newShot.id = UUID()

            project.shots.append(newShot)
            project.shotOrder.insert(newShot.id, at: sourceIndex + 1)

            let newBlock = ScheduleBlock(
                kind: .shot,
                shotID: newShot.id,
                title: "",
                durationSeconds: 0,
                scheduleNotes: ""
            )
            project.scheduleBlocks.append(newBlock)
        }
    }

    private func mutateProject(animated: Bool = false, syncScriptFromShots: Bool = true, _ mutate: (inout ProjectDocument) -> Void) {
        guard var project = activeProject, let activeProjectURL else {
            return
        }

        mutate(&project)
        if syncScriptFromShots {
            project.scriptText = scriptSync.composeScript(from: project)
        }
        project.updatedAt = Date()
        project.syncOrders()

        do {
            let resolvedProjectURL = try persistence.renameProjectFolderIfNeeded(currentFolderURL: activeProjectURL, projectTitle: project.title)
            try persistence.saveProject(project, to: resolvedProjectURL)
            self.activeProjectURL = resolvedProjectURL
            if animated {
                withAnimation(.snappy(duration: 0.26, extraBounce: 0.06)) {
                    activeProject = project
                }
            } else {
                activeProject = project
            }
            refreshLibrary()
        } catch {
            presentError(error)
        }
    }

    private func pickFile(allowedTypes: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}