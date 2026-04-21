import Foundation

struct ProjectPackagingService {
    private let fileManager = FileManager.default

    func exportProjectFolder(at folderURL: URL, to destinationURL: URL) throws {
        try runProcess(arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", folderURL.path, destinationURL.path])
    }

    func importProjectArchive(at archiveURL: URL, projectsDirectory: URL) throws -> URL {
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try runProcess(arguments: ["-x", "-k", archiveURL.path, temporaryRoot.path])

        let extractedItems = try fileManager.contentsOfDirectory(at: temporaryRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        guard let sourceFolder = extractedItems.first(where: { $0.hasDirectoryPath }) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let destinationFolder = uniqueFolderURL(named: sourceFolder.lastPathComponent, in: projectsDirectory)
        try fileManager.moveItem(at: sourceFolder, to: destinationFolder)
        return destinationFolder
    }

    private func uniqueFolderURL(named proposedName: String, in directory: URL) -> URL {
        var destinationURL = directory.appendingPathComponent(proposedName, isDirectory: true)
        var index = 2

        while fileManager.fileExists(atPath: destinationURL.path) {
            destinationURL = directory.appendingPathComponent("\(proposedName) \(index)", isDirectory: true)
            index += 1
        }

        return destinationURL
    }

    private func runProcess(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "ZIP operation failed."
            throw NSError(domain: "LakaiZipError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}