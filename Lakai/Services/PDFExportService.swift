import AppKit
import CoreGraphics
import CoreText
import Foundation

@MainActor
struct PDFExportService {
    func exportStoryboard(project: ProjectDocument, destinationURL: URL, activeProjectURL: URL?, persistence: ProjectPersistenceService) throws -> URL {
        let rows = project.orderedShots.enumerated().map { index, shot in
            StoryboardTableRow(
                shotNumber: index + 1,
                size: shot.size.title,
                description: shot.descriptionText,
                notes: shot.notes,
                imageFileName: shot.imageFileName
            )
        }

        try generateStoryboardPDF(
            project: project,
            rows: rows,
            destinationURL: destinationURL,
            activeProjectURL: activeProjectURL,
            persistence: persistence
        )

        return destinationURL
    }

    func exportSchedule(project: ProjectDocument, computation: ScheduleComputation, destinationURL: URL, activeProjectURL: URL?, persistence: ProjectPersistenceService) throws -> URL {
        let rows = computation.entries.map { entry in
            ScheduleTableRow(
                blockType: entry.block.kind == .pause ? "Pause" : "Shot",
                shotNumber: entry.shotNumber,
                size: entry.shot?.size.title ?? (entry.block.kind == .pause ? "" : "-"),
                setupStart: entry.setupStart.map(LakaiFormatters.timeString(from:)) ?? "-",
                shootStart: LakaiFormatters.timeString(from: entry.startTime),
                shootEnd: LakaiFormatters.timeString(from: entry.endTime),
                description: entry.block.kind == .pause ? entry.block.title : (entry.shot?.descriptionText ?? "-"),
                shotNotes: entry.shot?.notes ?? "",
                scheduleNotes: entry.block.scheduleNotes,
                imageFileName: entry.shot?.imageFileName
            )
        }

        try generateSchedulePDF(
            project: project,
            rows: rows,
            destinationURL: destinationURL,
            activeProjectURL: activeProjectURL,
            persistence: persistence
        )

        return destinationURL
    }

    // MARK: - Storyboard PDF

    private func generateStoryboardPDF(
        project: ProjectDocument,
        rows: [StoryboardTableRow],
        destinationURL: URL,
        activeProjectURL: URL?,
        persistence: ProjectPersistenceService
    ) throws {
        let pageSize = CGSize(width: 842, height: 595)
        let pageHeight = pageSize.height
        let pageWidth = pageSize.width
        let marginLeft: CGFloat = 28
        let marginRight: CGFloat = 28
        let marginTop: CGFloat = 28
        let marginBottom: CGFloat = 28
        let headerHeight: CGFloat = 80
        let rowHeight: CGFloat = 50

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(url: destinationURL as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "LakaiPDFError", code: 99, userInfo: [NSLocalizedDescriptionKey: "PDF context could not be created."])
        }

        var pageNumber = 0
        var currentY = pageHeight - marginTop

        // Helper to add a new page
        func beginNewPage() {
            if pageNumber > 0 {
                context.endPDFPage()
            }
            context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)
            pageNumber += 1
            currentY = pageHeight - marginTop
            
            // Draw page header
            let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil)
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
            let titleAS = NSAttributedString(string: project.title, attributes: titleAttrs)
            let titleLine = CTLineCreateWithAttributedString(titleAS)
            context.textPosition = CGPoint(x: marginLeft, y: currentY)
            CTLineDraw(titleLine, context)
            currentY -= 28

            // Metadata
            let smallFont = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
            let smallAttrs: [NSAttributedString.Key: Any] = [.font: smallFont]
            let versionStr = "Version v\(project.storyboardVersion) | \(LakaiFormatters.exportDate.string(from: Date())) | \(rows.count) Shots"
            let versionAS = NSAttributedString(string: versionStr, attributes: smallAttrs)
            let versionLine = CTLineCreateWithAttributedString(versionAS)
            context.textPosition = CGPoint(x: marginLeft, y: currentY)
            CTLineDraw(versionLine, context)
            currentY -= 16
            
            // Column headers
            drawStoryboardHeaders(context: context, y: currentY, pageWidth: pageWidth, marginLeft: marginLeft, marginRight: marginRight)
            currentY -= 24
        }

        beginNewPage()

        for row in rows {
            if currentY - rowHeight < marginBottom {
                beginNewPage()
            }
            drawStoryboardRow(context: context, row: row, y: currentY, pageWidth: pageWidth, marginLeft: marginLeft, marginRight: marginRight, rowHeight: rowHeight, activeProjectURL: activeProjectURL, persistence: persistence)
            currentY -= rowHeight - 1
        }

        context.endPDFPage()
        context.closePDF()
    }

    private func drawStoryboardHeaders(context: CGContext, y: CGFloat, pageWidth: CGFloat, marginLeft: CGFloat, marginRight: CGFloat) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 9, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        
        let headers = ["Shot", "Größe", "Beschreibung", "Notiz", "Bild"]
        let widths: [CGFloat] = [40, 60, 200, 150, 80]
        
        var x = marginLeft
        for (header, width) in zip(headers, widths) {
            let attributedString = NSAttributedString(string: header, attributes: attrs)
            let line = CTLineCreateWithAttributedString(attributedString)
            context.textPosition = CGPoint(x: x + 2, y: y)
            CTLineDraw(line, context)
            x += width
        }
    }

    private func drawStoryboardRow(context: CGContext, row: StoryboardTableRow, y: CGFloat, pageWidth: CGFloat, marginLeft: CGFloat, marginRight: CGFloat, rowHeight: CGFloat, activeProjectURL: URL?, persistence: ProjectPersistenceService) {
        let tableWidth = pageWidth - marginLeft - marginRight
        
        // Background
        context.setFillColor(NSColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1).cgColor)
        context.fill(CGRect(x: marginLeft, y: y - rowHeight, width: tableWidth, height: rowHeight))
        
        // Border
        context.setStrokeColor(NSColor(red: 0.71, green: 0.71, blue: 0.69, alpha: 1).cgColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(x: marginLeft, y: y - rowHeight, width: tableWidth, height: rowHeight))
        
        let font = CTFontCreateWithName("Helvetica" as CFString, 9, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        
        let data = [
            String(row.shotNumber),
            row.size,
            row.description.prefix(30).description,
            row.notes.prefix(25).description,
            ""
        ]
        let widths: [CGFloat] = [40, 60, 200, 150, 80]
        
        var x = marginLeft
        for (i, (datum, width)) in zip(data, widths).enumerated() {
            if i < 4 {
                let attributedString = NSAttributedString(string: datum, attributes: attrs)
                let line = CTLineCreateWithAttributedString(attributedString)
                context.textPosition = CGPoint(x: x + 2, y: y - 14)
                CTLineDraw(line, context)
            } else {
                // Image cell
                if let imageFileName = row.imageFileName,
                   let activeProjectURL = activeProjectURL,
                   let imageURL = persistence.resolveAssetURL(fileName: imageFileName, in: activeProjectURL, subfolder: "Images"),
                   let nsImage = NSImage(contentsOf: imageURL),
                   let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let imgRect = CGRect(x: x + 2, y: y - rowHeight + 2, width: width - 4, height: rowHeight - 4)
                    context.draw(cgImage, in: imgRect)
                }
            }
            x += width
        }
    }

    // MARK: - Schedule PDF

    private func generateSchedulePDF(
        project: ProjectDocument,
        rows: [ScheduleTableRow],
        destinationURL: URL,
        activeProjectURL: URL?,
        persistence: ProjectPersistenceService
    ) throws {
        let pageSize = CGSize(width: 842, height: 595)
        let pageHeight = pageSize.height
        let pageWidth = pageSize.width
        let marginLeft: CGFloat = 28
        let marginRight: CGFloat = 28
        let marginTop: CGFloat = 28
        let marginBottom: CGFloat = 28
        let headerHeight: CGFloat = 130
        let rowHeight: CGFloat = 38

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(url: destinationURL as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "LakaiPDFError", code: 99, userInfo: [NSLocalizedDescriptionKey: "PDF context could not be created."])
        }

        var pageNumber = 0
        var currentY = pageHeight - marginTop

        func beginNewPage() {
            if pageNumber > 0 {
                context.endPDFPage()
            }
            context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)
            pageNumber += 1
            currentY = pageHeight - marginTop
            drawSchedulePageHeader(context: context, project: project, y: currentY, pageWidth: pageWidth, marginLeft: marginLeft, activeProjectURL: activeProjectURL, persistence: persistence)
            currentY -= headerHeight
            drawScheduleHeaders(context: context, y: currentY, pageWidth: pageWidth, marginLeft: marginLeft, marginRight: marginRight)
            currentY -= 18
        }

        beginNewPage()

        for row in rows {
            if currentY - rowHeight < marginBottom {
                beginNewPage()
            }
            drawScheduleRow(context: context, row: row, y: currentY, pageWidth: pageWidth, marginLeft: marginLeft, marginRight: marginRight, rowHeight: rowHeight, activeProjectURL: activeProjectURL, persistence: persistence)
            currentY -= rowHeight - 1
        }

        context.endPDFPage()
        context.closePDF()
    }

    private func drawSchedulePageHeader(context: CGContext, project: ProjectDocument, y: CGFloat, pageWidth: CGFloat, marginLeft: CGFloat, activeProjectURL: URL?, persistence: ProjectPersistenceService) {
        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
        let titleAS = NSAttributedString(string: project.title, attributes: titleAttrs)
        let titleLine = CTLineCreateWithAttributedString(titleAS)
        context.textPosition = CGPoint(x: marginLeft, y: y)
        CTLineDraw(titleLine, context)

        let smallFont = CTFontCreateWithName("Helvetica" as CFString, 8, nil)
        let smallAttrs: [NSAttributedString.Key: Any] = [.font: smallFont]
        
        var textY = y - 18
        let infoLines = [
            "Version v\(project.scheduleVersion) | \(LakaiFormatters.exportDate.string(from: Date()))",
            "Drehtag: \(LakaiFormatters.shootDate.string(from: project.scheduleSettings.shootDate)) | Start: \(LakaiFormatters.timeString(from: project.scheduleSettings.shootStartMinutes * 60))",
            "Regie: \(project.crewInfo.director.isEmpty ? "-" : project.crewInfo.director) | 1st AD: \(project.crewInfo.firstAD.isEmpty ? "-" : project.crewInfo.firstAD) | Producer: \(project.crewInfo.producer.isEmpty ? "-" : project.crewInfo.producer)",
            "DoP: \(project.crewInfo.dop.isEmpty ? "-" : project.crewInfo.dop) | Kunde: \(project.crewInfo.client.isEmpty ? "-" : project.crewInfo.client)"
        ]
        
        for line in infoLines {
            let attributedString = NSAttributedString(string: line, attributes: smallAttrs)
            let ctLine = CTLineCreateWithAttributedString(attributedString)
            context.textPosition = CGPoint(x: marginLeft, y: textY)
            CTLineDraw(ctLine, context)
            textY -= 12
        }
    }

    private func drawScheduleHeaders(context: CGContext, y: CGFloat, pageWidth: CGFloat, marginLeft: CGFloat, marginRight: CGFloat) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 8, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        
        let headers = ["Shot", "Typ", "Setup", "Start", "Ende", "Beschreibung", "S-Notizen", "P-Notizen", "Bild"]
        let widths: [CGFloat] = [35, 35, 40, 40, 40, 150, 80, 80, 50]
        
        var x = marginLeft
        for (header, width) in zip(headers, widths) {
            let attributedString = NSAttributedString(string: header, attributes: attrs)
            let line = CTLineCreateWithAttributedString(attributedString)
            context.textPosition = CGPoint(x: x + 1, y: y)
            CTLineDraw(line, context)
            x += width
        }
    }

    private func drawScheduleRow(context: CGContext, row: ScheduleTableRow, y: CGFloat, pageWidth: CGFloat, marginLeft: CGFloat, marginRight: CGFloat, rowHeight: CGFloat, activeProjectURL: URL?, persistence: ProjectPersistenceService) {
        let tableWidth = pageWidth - marginLeft - marginRight
        
        // Background
        context.setFillColor(NSColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1).cgColor)
        context.fill(CGRect(x: marginLeft, y: y - rowHeight, width: tableWidth, height: rowHeight))
        
        // Border
        context.setStrokeColor(NSColor(red: 0.71, green: 0.71, blue: 0.69, alpha: 1).cgColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(x: marginLeft, y: y - rowHeight, width: tableWidth, height: rowHeight))
        
        let font = CTFontCreateWithName("Helvetica" as CFString, 8, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        
        let data = [
            row.shotNumber.map(String.init) ?? "-",
            row.blockType,
            row.setupStart,
            row.shootStart,
            row.shootEnd,
            row.description.prefix(25).description,
            row.shotNotes.prefix(15).description,
            row.scheduleNotes.prefix(15).description,
            ""
        ]
        let widths: [CGFloat] = [35, 35, 40, 40, 40, 150, 80, 80, 50]
        
        var x = marginLeft
        for (i, (datum, width)) in zip(data, widths).enumerated() {
            if i < 8 {
                let attributedString = NSAttributedString(string: datum, attributes: attrs)
                let line = CTLineCreateWithAttributedString(attributedString)
                context.textPosition = CGPoint(x: x + 1, y: y - 12)
                CTLineDraw(line, context)
            } else {
                // Image cell
                if let imageFileName = row.imageFileName,
                   let activeProjectURL = activeProjectURL,
                   let imageURL = persistence.resolveAssetURL(fileName: imageFileName, in: activeProjectURL, subfolder: "Images"),
                   let nsImage = NSImage(contentsOf: imageURL),
                   let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let imgRect = CGRect(x: x + 1, y: y - rowHeight + 1, width: width - 2, height: rowHeight - 2)
                    context.draw(cgImage, in: imgRect)
                }
            }
            x += width
        }
    }
}

// MARK: - Data Models

private struct StoryboardTableRow {
    let shotNumber: Int
    let size: String
    let description: String
    let notes: String
    let imageFileName: String?
}

private struct ScheduleTableRow {
    let blockType: String
    let shotNumber: Int?
    let size: String
    let setupStart: String
    let shootStart: String
    let shootEnd: String
    let description: String
    let shotNotes: String
    let scheduleNotes: String
    let imageFileName: String?
}