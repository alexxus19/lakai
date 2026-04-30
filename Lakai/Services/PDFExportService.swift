import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO

@MainActor
struct PDFExportService {
    func exportStoryboard(project: ProjectDocument, destinationURL: URL, activeProjectURL: URL?, persistence: ProjectPersistenceService) throws -> URL {
        var rows: [StoryboardTableRow] = []
        var sceneCount = 0

        for itemRef in project.shotlistItemOrder {
            switch itemRef.kind {
            case .sceneDivider:
                if let divider = project.sceneDivider(with: itemRef.id) {
                    sceneCount += 1
                    let headerText = divider.title.isEmpty
                        ? "Szene \(sceneCount)"
                        : "Szene \(sceneCount) – \(divider.title)"
                    rows.append(StoryboardTableRow(
                        shotNumber: "",
                        size: "",
                        description: "",
                        notes: "",
                        imageFileName: nil,
                        backgroundColor: nil,
                        sceneHeaderTitle: headerText
                    ))
                }
            case .shot:
                if let shot = project.shot(with: itemRef.id) {
                    rows.append(StoryboardTableRow(
                        shotNumber: project.displayShotNumber(for: shot.id).replacingOccurrences(of: "(opt)", with: "\n(opt)"),
                        size: shot.size.title,
                        description: shot.descriptionText,
                        notes: shot.notes,
                        imageFileName: shot.imageFileName,
                        backgroundColor: shot.isOptional ? "F3F3F3" : shot.backgroundColor
                    ))
                }
            }
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
        let setupStartTime = project.scheduleSettings.shootStartMinutes * 60
        let setupEndTime = setupStartTime + max(project.scheduleSettings.setupDurationSeconds, 0)

        var rows: [ScheduleTableRow] = [
            ScheduleTableRow(
                rowKind: .setup,
                shotLabel: "Setup",
                size: "",
                setupStart: "",
                shootStart: LakaiFormatters.timeString(from: setupStartTime),
                shootEnd: LakaiFormatters.timeString(from: setupEndTime),
                description: project.scheduleSettings.setupTitle,
                shotNotes: "",
                scheduleNotes: "",
                imageFileName: nil,
                backgroundColor: nil
            )
        ]

        rows.append(contentsOf: computation.entries.map { entry in
            let kind = entry.block.kind
            if kind == .dayHeader {
                return ScheduleTableRow(
                    rowKind: .dayHeader,
                    shotLabel: "",
                    size: "",
                    setupStart: "",
                    shootStart: "",
                    shootEnd: "",
                    description: "",
                    shotNotes: "",
                    scheduleNotes: "",
                    imageFileName: nil,
                    backgroundColor: nil,
                    dayDate: entry.block.date,
                    dayStartMinutes: entry.block.dayStartMinutes,
                    isBUnit: entry.block.isBUnit
                )
            }
            let isPause = kind == .pause
            let isOptional = !isPause && entry.shot?.isOptional == true
            let castNames: String = {
                guard let shot = entry.shot else { return "" }
                let memberLookup = Dictionary(uniqueKeysWithValues: project.castMembers.map { ($0.id, $0.name) })
                return shot.castMemberIDs.compactMap { memberLookup[$0] }.joined(separator: ", ")
            }()
            return ScheduleTableRow(
                rowKind: isPause ? .pause : .shot,
                shotLabel: isPause ? "Pause" : (entry.shot.map { project.displayShotNumber(for: $0.id).replacingOccurrences(of: "(opt)", with: "\n(opt)") } ?? ""),
                size: entry.shot?.size.title ?? "",
                setupStart: isOptional ? "" : (entry.setupStart.map(LakaiFormatters.timeString(from:)) ?? ""),
                shootStart: isOptional ? "" : LakaiFormatters.timeString(from: entry.startTime),
                shootEnd: isOptional ? "" : LakaiFormatters.timeString(from: entry.endTime),
                description: isPause ? entry.block.title : (entry.shot?.descriptionText ?? ""),
                shotNotes: entry.shot?.notes ?? "",
                scheduleNotes: entry.block.scheduleNotes,
                castNames: castNames,
                imageFileName: entry.shot?.imageFileName,
                backgroundColor: isPause ? entry.block.backgroundColor : (isOptional ? "F3F3F3" : entry.shot?.backgroundColor)
            )
        })

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
        let metrics = PDFPageMetrics(pageSize: pageSize)
        let columns = storyboardColumns(for: metrics)

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(url: destinationURL as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "LakaiPDFError", code: 99, userInfo: [NSLocalizedDescriptionKey: "PDF context could not be created."])
        }

        var pageNumber = 0
        var currentY: CGFloat = 0

        func beginNewPage() {
            if pageNumber > 0 {
                context.endPDFPage()
            }
            context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)
            pageNumber += 1
            currentY = metrics.pageHeight - metrics.marginTop

            fillPageBackground(context: context, mediaBox: mediaBox)
            drawPageNumber(context: context, pageNumber: pageNumber, metrics: metrics, mediaBox: mediaBox)
            currentY = drawStoryboardPageHeader(context: context, project: project, shotCount: rows.count, metrics: metrics, startY: currentY)
            currentY = drawTableHeader(context: context, columns: columns, metrics: metrics, baselineY: currentY)
        }

        beginNewPage()

        for row in rows {
            if let headerTitle = row.sceneHeaderTitle {
                // Scene divider header band — slim full-width row.
                let headerHeight: CGFloat = 22
                if currentY - headerHeight < metrics.marginBottom {
                    beginNewPage()
                }
                drawSceneHeaderBand(context: context, title: headerTitle, metrics: metrics, topY: currentY, height: headerHeight)
                currentY -= headerHeight
                continue
            }

            let rowHeight = storyboardRowHeight(row: row, columns: columns, metrics: metrics)
            if currentY - rowHeight < metrics.marginBottom {
                beginNewPage()
            }
            drawStoryboardRow(
                context: context,
                row: row,
                columns: columns,
                metrics: metrics,
                topY: currentY,
                rowHeight: rowHeight,
                activeProjectURL: activeProjectURL,
                persistence: persistence
            )
            currentY -= rowHeight
        }

        context.endPDFPage()
        context.closePDF()
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
        let metrics = PDFPageMetrics(pageSize: pageSize)
        let columns = scheduleColumns(for: metrics)

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(url: destinationURL as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "LakaiPDFError", code: 99, userInfo: [NSLocalizedDescriptionKey: "PDF context could not be created."])
        }

        var pageNumber = 0
        var currentY: CGFloat = 0
        var currentDayDate: Date? = nil
        var currentDayStartMinutes: Int = project.scheduleSettings.shootStartMinutes
        var currentDayIsBUnit: Bool = false

        func beginNewPage() {
            if pageNumber > 0 {
                context.endPDFPage()
            }
            context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)
            pageNumber += 1
            currentY = metrics.pageHeight - metrics.marginTop

            fillPageBackground(context: context, mediaBox: mediaBox)
            drawPageNumber(context: context, pageNumber: pageNumber, metrics: metrics, mediaBox: mediaBox)
            currentY = drawSchedulePageHeader(
                context: context,
                project: project,
                metrics: metrics,
                startY: currentY,
                currentDayDate: currentDayDate,
                currentDayStartMinutes: currentDayStartMinutes,
                isBUnit: currentDayIsBUnit,
                activeProjectURL: activeProjectURL,
                persistence: persistence
            )
            currentY = drawTableHeader(context: context, columns: columns, metrics: metrics, baselineY: currentY)
        }

        beginNewPage()

        for row in rows {
            // Day header rows force a new page rather than render as a table row
            if row.rowKind == .dayHeader {
                currentDayDate = row.dayDate
                currentDayStartMinutes = row.dayStartMinutes
                currentDayIsBUnit = row.isBUnit
                beginNewPage()
                continue
            }

            let rowHeight = scheduleRowHeight(row: row, columns: columns, metrics: metrics)
            if currentY - rowHeight < metrics.marginBottom {
                beginNewPage()
            }
            drawScheduleRow(
                context: context,
                row: row,
                columns: columns,
                metrics: metrics,
                topY: currentY,
                rowHeight: rowHeight,
                activeProjectURL: activeProjectURL,
                persistence: persistence
            )
            currentY -= rowHeight
        }

        context.endPDFPage()
        context.closePDF()
    }

    private func drawStoryboardPageHeader(context: CGContext, project: ProjectDocument, shotCount: Int, metrics: PDFPageMetrics, startY: CGFloat) -> CGFloat {
        var y = startY
        let titleRect = CGRect(x: metrics.marginLeft, y: y - 26, width: metrics.tableWidth, height: 26)
        drawWrappedText("\(project.title) - Storyboard", in: titleRect, context: context, font: metrics.headerFont, alignment: .left)
        y -= 28

        let meta = "Version v\(project.storyboardVersion) | Export: \(LakaiFormatters.exportDate.string(from: Date())) | Shots: \(shotCount)"
        let metaRect = CGRect(x: metrics.marginLeft, y: y - 14, width: metrics.tableWidth, height: 14)
        drawWrappedText(meta, in: metaRect, context: context, font: metrics.metaFont, alignment: .left)
        y -= 22
        return y
    }

    private func drawSchedulePageHeader(
        context: CGContext,
        project: ProjectDocument,
        metrics: PDFPageMetrics,
        startY: CGFloat,
        currentDayDate: Date?,
        currentDayStartMinutes: Int,
        isBUnit: Bool,
        activeProjectURL: URL?,
        persistence: ProjectPersistenceService
    ) -> CGFloat {
        var y = startY
        let logoReserveWidth = drawScheduleLogos(
            context: context,
            project: project,
            metrics: metrics,
            topY: y,
            activeProjectURL: activeProjectURL,
            persistence: persistence
        )

        let displayDate = currentDayDate ?? project.scheduleSettings.shootDate
        let displayStartMinutes = currentDayDate != nil ? currentDayStartMinutes : project.scheduleSettings.shootStartMinutes
        let bUnitSuffix = isBUnit ? " (B-Unit)" : ""

        let textWidth = max(metrics.tableWidth - logoReserveWidth - 8, 260)
        let titleRect = CGRect(x: metrics.marginLeft, y: y - 26, width: textWidth, height: 26)
        drawWrappedText("\(project.title) - Drehplan", in: titleRect, context: context, font: metrics.headerFont, alignment: .left)
        y -= 28

        let infoLines = [
            "Version v\(project.scheduleVersion) | Export: \(LakaiFormatters.exportDate.string(from: Date()))",
            "Drehtag: \(LakaiFormatters.shootDate.string(from: displayDate))\(bUnitSuffix) | Start: \(LakaiFormatters.timeString(from: displayStartMinutes * 60))",
            "Regie: \(project.crewInfo.director) | 1st AD: \(project.crewInfo.firstAD) | Producer: \(project.crewInfo.producer)",
            "DoP: \(project.crewInfo.dop) | Kunde: \(project.crewInfo.client)",
            "Location: \(project.crewInfo.location) | Props: \(project.crewInfo.props)"
        ]

        for line in infoLines {
            let lineRect = CGRect(x: metrics.marginLeft, y: y - 12, width: textWidth, height: 12)
            drawWrappedText(line, in: lineRect, context: context, font: metrics.metaFont, alignment: .left)
            y -= 14
        }

        y -= 4
        return y
    }

    private func drawTableHeader(context: CGContext, columns: [PDFColumn], metrics: PDFPageMetrics, baselineY: CGFloat) -> CGFloat {
        let rect = CGRect(x: metrics.marginLeft, y: baselineY - metrics.headerRowHeight, width: metrics.tableWidth, height: metrics.headerRowHeight)
        context.setFillColor(NSColor(white: 0.94, alpha: 1).cgColor)
        context.fill(rect)

        drawGrid(context: context, columns: columns, rowRect: rect, strokeColor: NSColor(white: 0.65, alpha: 1))

        var x = metrics.marginLeft
        for column in columns {
            let textRect = CGRect(
                x: x + metrics.cellHorizontalPadding,
                y: rect.minY + 3,
                width: column.width - (metrics.cellHorizontalPadding * 2),
                height: rect.height - 6
            )
            drawWrappedText(column.title, in: textRect, context: context, font: metrics.boldFont, alignment: column.alignment)
            x += column.width
        }

        return rect.minY
    }

    private func storyboardRowHeight(row: StoryboardTableRow, columns: [PDFColumn], metrics: PDFPageMetrics) -> CGFloat {
        let descriptionColumn = columns.first(where: { $0.key == .description })?.width ?? 0
        let notesColumn = columns.first(where: { $0.key == .notes })?.width ?? 0
        let imageColumn = columns.first(where: { $0.key == .image })?.width ?? 0

        let descriptionHeight = measuredTextHeight(row.description, width: descriptionColumn - (metrics.cellHorizontalPadding * 2), font: metrics.boldFont)
        let notesHeight = measuredTextHeight(row.notes, width: notesColumn - (metrics.cellHorizontalPadding * 2), font: metrics.bodyFont)
        let imageHeight = max(0, (imageColumn - (metrics.cellHorizontalPadding * 2)) * 9 / 16)

        let contentHeight = max(max(descriptionHeight, notesHeight), imageHeight)
        return max(metrics.minimumStoryboardRowHeight, contentHeight + (metrics.cellVerticalPadding * 2))
    }

    private func scheduleRowHeight(row: ScheduleTableRow, columns: [PDFColumn], metrics: PDFPageMetrics) -> CGFloat {
        let descriptionColumn = columns.first(where: { $0.key == .description })?.width ?? 0
        let shotNotesColumn = columns.first(where: { $0.key == .shotNotes })?.width ?? 0
        let scheduleNotesColumn = columns.first(where: { $0.key == .scheduleNotes })?.width ?? 0
        let imageColumn = columns.first(where: { $0.key == .image })?.width ?? 0

        let descriptionHeight = measuredTextHeight(row.description, width: descriptionColumn - (metrics.cellHorizontalPadding * 2), font: metrics.scheduleBodyFont)
        let shotNotesHeight = measuredTextHeight(row.shotNotes, width: shotNotesColumn - (metrics.cellHorizontalPadding * 2), font: metrics.scheduleBodyFont)
        let scheduleNotesHeight = measuredTextHeight(row.scheduleNotes, width: scheduleNotesColumn - (metrics.cellHorizontalPadding * 2), font: metrics.scheduleBodyFont)
        let imageHeight = max(0, (imageColumn - (metrics.cellHorizontalPadding * 2)) * 9 / 16)

        let contentHeight = max(max(descriptionHeight, shotNotesHeight), max(scheduleNotesHeight, imageHeight))
        return max(metrics.minimumScheduleRowHeight, contentHeight + (metrics.cellVerticalPadding * 2))
    }

    private func drawSceneHeaderBand(context: CGContext, title: String, metrics: PDFPageMetrics, topY: CGFloat, height: CGFloat) {
        let bandRect = CGRect(x: metrics.marginLeft, y: topY - height, width: metrics.tableWidth, height: height)
        // Light gray fill
        context.setFillColor(NSColor(white: 0.90, alpha: 1).cgColor)
        context.fill(bandRect)
        // Bottom border
        context.setStrokeColor(NSColor(white: 0.72, alpha: 1).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: bandRect.minX, y: bandRect.minY))
        context.addLine(to: CGPoint(x: bandRect.maxX, y: bandRect.minY))
        context.strokePath()
        // Text
        let textRect = CGRect(
            x: bandRect.minX + metrics.cellHorizontalPadding,
            y: bandRect.minY + 4,
            width: bandRect.width - (metrics.cellHorizontalPadding * 2),
            height: bandRect.height - 6
        )
        drawWrappedText(title, in: textRect, context: context, font: metrics.boldFont, alignment: .left)
    }

    private func drawStoryboardRow(
        context: CGContext,
        row: StoryboardTableRow,
        columns: [PDFColumn],
        metrics: PDFPageMetrics,
        topY: CGFloat,
        rowHeight: CGFloat,
        activeProjectURL: URL?,
        persistence: ProjectPersistenceService
    ) {
        let rowRect = CGRect(x: metrics.marginLeft, y: topY - rowHeight, width: metrics.tableWidth, height: rowHeight)
        
        // Set fill color based on backgroundColor
        if let bgHex = row.backgroundColor, let rgbColor = hexToRGB(bgHex) {
            context.setFillColor(rgbColor.cgColor)
        } else {
            context.setFillColor(NSColor.white.cgColor)
        }
        context.fill(rowRect)
        
        drawGrid(context: context, columns: columns, rowRect: rowRect, strokeColor: NSColor(white: 0.72, alpha: 1))

        var x = metrics.marginLeft
        for column in columns {
            let cellRect = CGRect(x: x, y: rowRect.minY, width: column.width, height: rowRect.height)
            let contentRect = CGRect(
                x: cellRect.minX + metrics.cellHorizontalPadding,
                y: cellRect.minY + metrics.cellVerticalPadding,
                width: cellRect.width - (metrics.cellHorizontalPadding * 2),
                height: cellRect.height - (metrics.cellVerticalPadding * 2)
            )

            switch column.key {
            case .shotNumber:
                drawWrappedText(row.shotNumber, in: contentRect, context: context, font: metrics.boldFont, alignment: .center)
            case .size:
                drawWrappedText(row.size, in: contentRect, context: context, font: metrics.bodyFont, alignment: .left)
            case .description:
                drawWrappedText(row.description, in: contentRect, context: context, font: metrics.boldFont, alignment: .left)
            case .notes:
                drawWrappedText(row.notes, in: contentRect, context: context, font: metrics.bodyFont, alignment: .left)
            case .image:
                drawImageIfAvailable(imageFileName: row.imageFileName, in: contentRect, context: context, targetPPI: 300, activeProjectURL: activeProjectURL, persistence: persistence)
            default:
                break
            }

            x += column.width
        }
    }

    private func drawScheduleRow(
        context: CGContext,
        row: ScheduleTableRow,
        columns: [PDFColumn],
        metrics: PDFPageMetrics,
        topY: CGFloat,
        rowHeight: CGFloat,
        activeProjectURL: URL?,
        persistence: ProjectPersistenceService
    ) {
        let rowRect = CGRect(x: metrics.marginLeft, y: topY - rowHeight, width: metrics.tableWidth, height: rowHeight)
        
        let fillColor: NSColor
        if let bgHex = row.backgroundColor, let rgbColor = hexToRGB(bgHex) {
            fillColor = rgbColor
        } else {
            switch row.rowKind {
            case .pause:
                fillColor = NSColor(white: 0.94, alpha: 1)
            case .setup, .shot, .dayHeader:
                fillColor = .white
            }
        }

        context.setFillColor(fillColor.cgColor)
        context.fill(rowRect)
        drawGrid(context: context, columns: columns, rowRect: rowRect, strokeColor: NSColor(white: 0.72, alpha: 1))

        var x = metrics.marginLeft
        for column in columns {
            let cellRect = CGRect(x: x, y: rowRect.minY, width: column.width, height: rowRect.height)
            let contentRect = CGRect(
                x: cellRect.minX + metrics.cellHorizontalPadding,
                y: cellRect.minY + metrics.cellVerticalPadding,
                width: cellRect.width - (metrics.cellHorizontalPadding * 2),
                height: cellRect.height - (metrics.cellVerticalPadding * 2)
            )

            switch column.key {
            case .shotNumber:
                drawWrappedText(row.shotLabel, in: contentRect, context: context, font: metrics.scheduleBodyFont, alignment: .center)
            case .size:
                drawWrappedText(row.size, in: contentRect, context: context, font: metrics.scheduleBodyFont, alignment: .left)
            case .cast:
                drawWrappedText(row.castNames, in: contentRect, context: context, font: metrics.scheduleBodyFont, alignment: .left)
            case .setupStart:
                drawWrappedText(row.setupStart, in: contentRect, context: context, font: metrics.scheduleBodyFont, alignment: .center)
            case .shootStart:
                drawWrappedText(row.shootStart, in: contentRect, context: context, font: metrics.scheduleBodyFont, alignment: .center)
            case .shootEnd:
                drawWrappedText(row.shootEnd, in: contentRect, context: context, font: metrics.scheduleBodyFont, alignment: .center)
            case .description:
                drawWrappedText(row.description, in: contentRect, context: context, font: metrics.scheduleBodyFont, alignment: .left)
            case .shotNotes:
                drawWrappedText(row.shotNotes, in: contentRect, context: context, font: metrics.scheduleBodyFont, alignment: .left)
            case .scheduleNotes:
                drawWrappedText(row.scheduleNotes, in: contentRect, context: context, font: metrics.scheduleBodyFont, alignment: .left)
            case .notes:
                break
            case .image:
                drawImageIfAvailable(imageFileName: row.imageFileName, in: contentRect, context: context, targetPPI: 150, activeProjectURL: activeProjectURL, persistence: persistence)
            }

            x += column.width
        }
    }

    private func fillPageBackground(context: CGContext, mediaBox: CGRect) {
        context.setFillColor(NSColor.white.cgColor)
        context.fill(mediaBox)
    }

    private func drawPageNumber(context: CGContext, pageNumber: Int, metrics: PDFPageMetrics, mediaBox: CGRect) {
        let label = "Seite \(pageNumber)"
        let textHeight: CGFloat = 10
        let textRect = CGRect(
            x: mediaBox.minX + metrics.marginLeft,
            y: mediaBox.minY + (metrics.marginBottom - textHeight) / 2,
            width: mediaBox.width - metrics.marginLeft - metrics.marginRight,
            height: textHeight
        )
        drawWrappedText(label, in: textRect, context: context, font: metrics.metaFont, alignment: .center)
    }

    private func hexToRGB(_ hex: String) -> NSColor? {
        let trimmed = hex.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count == 6 else { return nil }

        let scanner = Scanner(string: trimmed)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }

        let red = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgb & 0xFF) / 255.0

        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
    }

    private func drawGrid(context: CGContext, columns: [PDFColumn], rowRect: CGRect, strokeColor: NSColor) {
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(0.6)
        context.stroke(rowRect)

        var x = rowRect.minX
        for column in columns.dropLast() {
            x += column.width
            context.move(to: CGPoint(x: x, y: rowRect.minY))
            context.addLine(to: CGPoint(x: x, y: rowRect.maxY))
            context.strokePath()
        }
    }

    private func drawImageIfAvailable(
        imageFileName: String?,
        in rect: CGRect,
        context: CGContext,
        targetPPI: CGFloat,
        activeProjectURL: URL?,
        persistence: ProjectPersistenceService
    ) {
        guard let imageFileName,
              let activeProjectURL,
              let imageURL = persistence.resolveAssetURL(fileName: imageFileName, in: activeProjectURL, subfolder: "Images") else {
            return
        }

        guard let cgImage = loadCGImage(from: imageURL) else {
            return
        }

        let drawRect = aspectFitRect(for: cgImage, in: rect)
        let displayImage = downsampleToJPEG(cgImage, drawRect: drawRect, targetPPI: targetPPI) ?? cgImage
        context.interpolationQuality = .high
        context.draw(displayImage, in: drawRect)
    }

    /// Downsample `image` to the given PPI relative to the 72pt PDF coordinate space,
    /// then JPEG-encode it so Core Graphics embeds a compressed JPEG stream in the PDF.
    private func downsampleToJPEG(_ image: CGImage, drawRect: CGRect, targetPPI: CGFloat) -> CGImage? {
        let scale = targetPPI / 72.0
        let targetWidth = Int(ceil(drawRect.width * scale))
        let targetHeight = Int(ceil(drawRect.height * scale))

        // Skip upsampling: only downsample when source is larger.
        guard targetWidth > 0, targetHeight > 0,
              targetWidth < image.width || targetHeight < image.height else {
            return nil
        }

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let bitmapCtx = CGContext(
                data: nil,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            return nil
        }

        bitmapCtx.interpolationQuality = .high
        bitmapCtx.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let downsampled = bitmapCtx.makeImage() else { return nil }

        // JPEG-encode so the PDF embeds a compact JPEG stream.
        let rep = NSBitmapImageRep(cgImage: downsampled)
        guard let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75]),
              let source = CGImageSourceCreateWithData(jpegData as CFData, nil),
              let jpegImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        return jpegImage
    }

    private func loadCGImage(from imageURL: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            if let nsImage = NSImage(contentsOf: imageURL) {
                return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
            return nil
        }

        return image
    }

    private func aspectFitRect(for image: CGImage, in bounds: CGRect) -> CGRect {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        guard imageWidth > 0, imageHeight > 0 else {
            return bounds
        }

        let widthScale = bounds.width / imageWidth
        let heightScale = bounds.height / imageHeight
        let scale = min(widthScale, heightScale)

        let targetWidth = imageWidth * scale
        let targetHeight = imageHeight * scale
        let originX = bounds.minX + (bounds.width - targetWidth) / 2
        let originY = bounds.minY + (bounds.height - targetHeight) / 2

        return CGRect(x: originX, y: originY, width: targetWidth, height: targetHeight)
    }

    private func measuredTextHeight(_ text: String, width: CGFloat, font: NSFont) -> CGFloat {
        guard width > 0 else {
            return 0
        }

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = normalized.isEmpty ? " " : text
        let attributed = attributedText(content, font: font, alignment: .left)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let target = CGSize(width: width, height: .greatestFiniteMagnitude)
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: attributed.length), nil, target, nil)
        return ceil(max(measured.height, font.pointSize + 2))
    }

    private func drawWrappedText(_ text: String, in rect: CGRect, context: CGContext, font: NSFont, alignment: NSTextAlignment) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        let attributed = attributedText(text, font: font, alignment: alignment)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let path = CGMutablePath()
        path.addRect(rect)

        context.saveGState()
        context.textMatrix = .identity

        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributed.length), path, nil)
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private func drawScheduleLogos(
        context: CGContext,
        project: ProjectDocument,
        metrics: PDFPageMetrics,
        topY: CGFloat,
        activeProjectURL: URL?,
        persistence: ProjectPersistenceService
    ) -> CGFloat {
        guard let activeProjectURL else {
            return 0
        }

        let logoImages = [project.crewInfo.productionLogoFileName, project.crewInfo.clientLogoFileName]
            .compactMap { $0 }
            .compactMap { fileName -> CGImage? in
                guard let logoURL = persistence.resolveAssetURL(fileName: fileName, in: activeProjectURL, subfolder: "Logos") else {
                    return nil
                }
                return loadCGImage(from: logoURL)
            }

        guard !logoImages.isEmpty else {
            return 0
        }

        let boxWidth: CGFloat = 84
        let boxHeight: CGFloat = 34
        let spacing: CGFloat = 8
        let logosWidth = (CGFloat(logoImages.count) * boxWidth) + (CGFloat(max(logoImages.count - 1, 0)) * spacing)
        let startX = metrics.marginLeft + metrics.tableWidth - logosWidth
        let startY = topY - boxHeight

        for (index, logoImage) in logoImages.enumerated() {
            let x = startX + CGFloat(index) * (boxWidth + spacing)
            let logoRect = CGRect(x: x, y: startY, width: boxWidth, height: boxHeight)
            let drawRect = aspectFitRect(for: logoImage, in: logoRect)
            context.interpolationQuality = .high
            context.draw(logoImage, in: drawRect)
        }

        return logosWidth
    }

    private func attributedText(_ text: String, font: NSFont, alignment: NSTextAlignment) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1.2

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func storyboardColumns(for metrics: PDFPageMetrics) -> [PDFColumn] {
        [
            PDFColumn(title: "Shot", key: .shotNumber, width: 40, alignment: .center),
            PDFColumn(title: "Groesse", key: .size, width: 80, alignment: .left),
            PDFColumn(title: "Beschreibung", key: .description, width: 250, alignment: .left),
            PDFColumn(title: "Notizen", key: .notes, width: 220, alignment: .left),
            PDFColumn(title: "Storyboard", key: .image, width: metrics.tableWidth - 590, alignment: .left)
        ]
    }

    private func scheduleColumns(for metrics: PDFPageMetrics) -> [PDFColumn] {
        // Fixed-width columns — values chosen to be as compact as their content allows.
        let shotW: CGFloat = 44
        let setupW: CGFloat = 36
        let startW: CGFloat = 36
        let endeW: CGFloat = 36
        let groesseW: CGFloat = 56
        let castW: CGFloat = 72
        let shotNotesW: CGFloat = 96
        let planNotesW: CGFloat = 96
        let bildW: CGFloat = 94
        // Beschreibung gets all remaining space.
        let beschreibungW = metrics.tableWidth - shotW - setupW - startW - endeW - groesseW - castW - shotNotesW - planNotesW - bildW
        return [
            PDFColumn(title: "Shot", key: .shotNumber, width: shotW, alignment: .center),
            PDFColumn(title: "Setup", key: .setupStart, width: setupW, alignment: .center),
            PDFColumn(title: "Start", key: .shootStart, width: startW, alignment: .center),
            PDFColumn(title: "Ende", key: .shootEnd, width: endeW, alignment: .center),
            PDFColumn(title: "Groesse", key: .size, width: groesseW, alignment: .left),
            PDFColumn(title: "Cast", key: .cast, width: castW, alignment: .left),
            PDFColumn(title: "Beschreibung", key: .description, width: beschreibungW, alignment: .left),
            PDFColumn(title: "Shot-Notizen", key: .shotNotes, width: shotNotesW, alignment: .left),
            PDFColumn(title: "Plan-Notizen", key: .scheduleNotes, width: planNotesW, alignment: .left),
            PDFColumn(title: "Bild", key: .image, width: bildW, alignment: .left)
        ]
    }
}

private struct PDFPageMetrics {
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let marginLeft: CGFloat = 28
    let marginRight: CGFloat = 28
    let marginTop: CGFloat = 28
    let marginBottom: CGFloat = 28
    let headerRowHeight: CGFloat = 22
    let cellHorizontalPadding: CGFloat = 5
    let cellVerticalPadding: CGFloat = 4
    let minimumStoryboardRowHeight: CGFloat = 48
    let minimumScheduleRowHeight: CGFloat = 40
    let headerFont = NSFont.boldSystemFont(ofSize: 18)
    let boldFont = NSFont.boldSystemFont(ofSize: 9)
    let metaFont = NSFont.systemFont(ofSize: 9, weight: .regular)
    let bodyFont = NSFont.systemFont(ofSize: 8.5, weight: .regular)
    // Schedule table uses a smaller body font (-20%) for higher information density.
    let scheduleBodyFont = NSFont.systemFont(ofSize: 7, weight: .regular)

    init(pageSize: CGSize) {
        self.pageWidth = pageSize.width
        self.pageHeight = pageSize.height
    }

    var tableWidth: CGFloat {
        pageWidth - marginLeft - marginRight
    }
}

private struct PDFColumn {
    let title: String
    let key: PDFColumnKey
    let width: CGFloat
    let alignment: NSTextAlignment
}

private enum PDFColumnKey {
    case shotNumber
    case size
    case cast
    case setupStart
    case shootStart
    case shootEnd
    case description
    case notes
    case shotNotes
    case scheduleNotes
    case image
}

// MARK: - Data Models

private struct StoryboardTableRow {
    let shotNumber: String
    let size: String
    let description: String
    let notes: String
    let imageFileName: String?
    let backgroundColor: String?
    /// When set, the row renders as a full-width scene header band instead of a data row.
    var sceneHeaderTitle: String? = nil
}

private struct ScheduleTableRow {
    let rowKind: ScheduleTableRowKind
    let shotLabel: String
    let size: String
    let setupStart: String
    let shootStart: String
    let shootEnd: String
    let description: String
    let shotNotes: String
    let scheduleNotes: String
    let castNames: String
    let imageFileName: String?
    let backgroundColor: String?
    // Day header metadata (only used when rowKind == .dayHeader)
    let dayDate: Date?
    let dayStartMinutes: Int
    let isBUnit: Bool

    init(rowKind: ScheduleTableRowKind, shotLabel: String, size: String, setupStart: String, shootStart: String, shootEnd: String, description: String, shotNotes: String, scheduleNotes: String, castNames: String = "", imageFileName: String?, backgroundColor: String?, dayDate: Date? = nil, dayStartMinutes: Int = 0, isBUnit: Bool = false) {
        self.rowKind = rowKind
        self.shotLabel = shotLabel
        self.size = size
        self.setupStart = setupStart
        self.shootStart = shootStart
        self.shootEnd = shootEnd
        self.description = description
        self.shotNotes = shotNotes
        self.scheduleNotes = scheduleNotes
        self.castNames = castNames
        self.imageFileName = imageFileName
        self.backgroundColor = backgroundColor
        self.dayDate = dayDate
        self.dayStartMinutes = dayStartMinutes
        self.isBUnit = isBUnit
    }
}

private enum ScheduleTableRowKind {
    case setup
    case shot
    case pause
    case dayHeader
}