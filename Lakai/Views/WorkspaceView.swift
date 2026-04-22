import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @ObservedObject var appState: AppState
    private let scriptSync = ScriptSyncService()
    @State private var draggedShotID: UUID?
    @State private var draggedScheduleBlockID: UUID?
    @State private var localMouseUpMonitor: Any?
    @State private var globalMouseUpMonitor: Any?
    @State private var scheduleSetupDrafts: [UUID: String] = [:]
    @State private var scheduleDurationDrafts: [UUID: String] = [:]
    @State private var pauseDurationDrafts: [UUID: String] = [:]
    @State private var setupDurationDraft: String = ""
    @State private var isShootDatePickerPresented = false
    @State private var isShootTimePickerPresented = false

    private let dropGapHeight: CGFloat = 20

    var body: some View {
        if let project = appState.activeProject {
            ZStack {
                LinearGradient(colors: [LakaiTheme.canvas, LakaiTheme.canvasAlt], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    header(project)

                    Group {
                        if appState.currentMode == .script {
                            scriptView(project)
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                        } else if appState.currentMode == .shotlist {
                            shotlistView(project)
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                        } else {
                            scheduleView(project)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
                .padding(18)
            }
            .onAppear {
                syncDrafts(project)
                installDragStateResetMonitor()
            }
            .onChange(of: project.updatedAt) { _, _ in
                syncDrafts(project)
            }
            .onDisappear {
                removeDragStateResetMonitor()
            }
            .animation(.snappy(duration: 0.28, extraBounce: 0.04), value: appState.currentMode)
        }
    }

    private func header(_ project: ProjectDocument) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button("Übersicht") {
                    appState.closeProject()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(LakaiTheme.ink)

                TextField("Projekttitel", text: Binding(
                    get: { appState.activeProject?.title ?? "" },
                    set: { appState.updateProjectTitle($0) }
                ))
                .font(.system(size: 26, weight: .bold))
                .textFieldStyle(.plain)
                .foregroundStyle(LakaiTheme.ink)

                HStack(spacing: 8) {
                    versionPill(title: "Storyboard", value: "v\(project.storyboardVersion)")
                    versionPill(title: "Drehplan", value: "v\(project.scheduleVersion)")
                }

                Spacer(minLength: 0)

                modeSwitch

                Button("Projekt exportieren") {
                    appState.exportProjectArchive()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(LakaiTheme.ink)

                Button(appState.currentMode == .schedule ? "Drehplan PDF" : "Storyboard PDF") {
                    if appState.currentMode == .schedule {
                        appState.exportSchedulePDF()
                    } else {
                        appState.exportStoryboardPDF()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(LakaiTheme.accent)
                .foregroundStyle(LakaiTheme.ink)
            }

            HStack(alignment: .center, spacing: 10) {
                compactDateButton(title: "Drehtag", value: LakaiFormatters.shootDate.string(from: project.scheduleSettings.shootDate), isPresented: $isShootDatePickerPresented) {
                    DatePicker(
                        "Drehtag",
                        selection: Binding(
                            get: { project.scheduleSettings.shootDate },
                            set: {
                                appState.updateShootDate($0)
                                isShootDatePickerPresented = false
                            }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(10)
                    .frame(width: 280)
                }

                compactDateButton(title: "Drehstart", value: LakaiFormatters.timeString(from: project.scheduleSettings.shootStartMinutes * 60), isPresented: $isShootTimePickerPresented) {
                    DatePicker(
                        "Drehstart",
                        selection: Binding(
                            get: { date(fromMinutes: project.scheduleSettings.shootStartMinutes, on: project.scheduleSettings.shootDate) },
                            set: {
                                appState.updateShootStart($0)
                                isShootTimePickerPresented = false
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .padding(10)
                    .frame(width: 160)
                }

                compactField("Regie", value: project.crewInfo.director) { appState.updateCrewValue($0, at: \.director) }
                compactField("1st AD", value: project.crewInfo.firstAD) { appState.updateCrewValue($0, at: \.firstAD) }
                compactField("Producer", value: project.crewInfo.producer) { appState.updateCrewValue($0, at: \.producer) }
                compactField("Kunde", value: project.crewInfo.client) { appState.updateCrewValue($0, at: \.client) }
                compactField("DoP", value: project.crewInfo.dop) { appState.updateCrewValue($0, at: \.dop) }

                logoControls(kind: .client, imageURL: appState.logoURL(for: .client))
                logoControls(kind: .production, imageURL: appState.logoURL(for: .production))
            }
        }
        .padding(16)
        .background(LakaiTheme.panelElevated.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LakaiTheme.panelBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
    }

    private func scriptView(_ project: ProjectDocument) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skript")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(LakaiTheme.ink)
                    Text("Zeilen vor dem ersten Marker werden ignoriert. Neue Shots beginnen mit •, #, -, * oder [ ].")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LakaiTheme.mutedInk)
                }

                Spacer()

                Text("Erkannte Shotgrößen am Zeilenanfang werden kursiv markiert und in die Shotlist übernommen.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LakaiTheme.mutedInk)
                    .frame(maxWidth: 340, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            }

            ScriptTextEditor(
                text: Binding(
                    get: { appState.activeProject?.scriptText ?? "" },
                    set: { appState.updateScriptText($0) }
                ),
                scriptSync: scriptSync
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
            .background(LakaiTheme.panel.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(LakaiTheme.panelBorder, lineWidth: 1))

            HStack(spacing: 10) {
                metaPill(title: "Shots", value: String(project.shots.count))
                metaPill(title: "Storyboard", value: "v\(project.storyboardVersion)")
                metaPill(title: "Drehplan", value: "v\(project.scheduleVersion)")
            }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 0) {
            ForEach(WorkspaceMode.allCases) { mode in
                Button {
                    appState.switchMode(mode)
                } label: {
                    ZStack {
                        if appState.currentMode == mode {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LakaiTheme.accentStrong)
                        }

                        Text(mode.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(appState.currentMode == mode ? LakaiTheme.ink : LakaiTheme.mutedInk)
                    }
                    .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 306)
        .padding(3)
        .background(LakaiTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func shotlistView(_ project: ProjectDocument) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Shotlist")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(LakaiTheme.ink)

                    Spacer()

                    Button("Shot hinzufügen") {
                        appState.addShot()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(LakaiTheme.accent)
                    .foregroundStyle(LakaiTheme.ink)
                }

                LazyVStack(spacing: 10) {
                    ForEach(Array(project.orderedShots.enumerated()), id: \.element.id) { index, shot in
                        VStack(spacing: 0) {
                            ShotCardView(
                                shotNumber: index + 1,
                                shot: shot,
                                imageURL: appState.imageURL(for: shot),
                                mode: .shotlist,
                                onDelete: { appState.deleteShot(shot.id) },
                                onImportImage: { appState.importShotImage(for: shot.id) },
                                onRemoveImage: { appState.clearShotImage(shot.id) },
                                sizeBinding: Binding(
                                    get: { appState.activeProject?.shot(with: shot.id)?.size ?? .ms },
                                    set: { appState.updateShotSize(shot.id, size: $0) }
                                ),
                                descriptionBinding: Binding(
                                    get: { appState.activeProject?.shot(with: shot.id)?.descriptionText ?? "" },
                                    set: { appState.updateShotDescription(shot.id, text: $0) }
                                ),
                                notesBinding: Binding(
                                    get: { appState.activeProject?.shot(with: shot.id)?.notes ?? "" },
                                    set: { appState.updateShotNotes(shot.id, text: $0) }
                                ),
                                setupBinding: .constant(""),
                                durationBinding: .constant("")
                            )
                            .scaleEffect(draggedShotID == shot.id ? 1.01 : 1)
                            .overlay(reorderCardOverlay(isDragged: draggedShotID == shot.id))
                            .zIndex(draggedShotID == shot.id ? 2 : 0)
                            .onDrag {
                                draggedShotID = shot.id
                                return NSItemProvider(object: shot.id.uuidString as NSString)
                            } preview: {
                                dragPreviewPlaceholder
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: ReorderDropDelegate(
                                    itemID: shot.id,
                                    orderedIDsProvider: { appState.activeProject?.shotOrder ?? [] },
                                    draggedID: $draggedShotID,
                                    insertAfterTarget: true,
                                    onMove: { from, to in
                                        appState.moveItemLive(in: .shotlist, from: from, to: to)
                                    }
                                )
                            )
                        }
                    }
                }
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: draggedShotID)
            }
        }
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
            resetDragState()
            return true
        }
    }

    private func scheduleView(_ project: ProjectDocument) -> some View {
        let computation = appState.scheduleComputation()
        let entryLookup = Dictionary(uniqueKeysWithValues: (computation?.entries ?? []).map { ($0.id, $0) })
        let orderedBlocks = project.orderedScheduleBlocks

        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Drehplan")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(LakaiTheme.ink)

                    Spacer()

                    Button("Pause hinzufügen") {
                        appState.addPauseBlock()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(LakaiTheme.accent)
                    .foregroundStyle(LakaiTheme.ink)
                }

                setupCard(for: project)

                if let firstBlockID = orderedBlocks.first?.id,
                   draggedScheduleBlockID != nil {
                    scheduleTopDropZone(firstBlockID: firstBlockID)
                }

                LazyVStack(spacing: 10) {
                    ForEach(orderedBlocks, id: \.id) { block in
                        VStack(spacing: 0) {
                            if block.kind == .pause {
                                pauseCard(for: block, entry: entryLookup[block.id])
                            } else if let shotID = block.shotID,
                                      let shot = project.shot(with: shotID),
                                      let entry = entryLookup[block.id] {
                                scheduleShotCard(for: block, shot: shot, entry: entry, isLastBlock: orderedBlocks.last?.id == block.id)
                            }
                        }
                    }
                }
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: draggedScheduleBlockID)
            }
        }
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
            resetDragState()
            return true
        }
    }

    private func scheduleTopDropZone(firstBlockID: UUID) -> some View {
        dropGapView
            .onDrop(
                of: [UTType.text],
                delegate: ReorderDropDelegate(
                    itemID: firstBlockID,
                    orderedIDsProvider: { appState.activeProject?.orderedScheduleBlocks.map(\.id) ?? [] },
                    draggedID: $draggedScheduleBlockID,
                    insertAfterTarget: false,
                    onMove: { from, to in
                        appState.moveItemLive(in: .schedule, from: from, to: to)
                    }
                )
            )
    }

    private func setupCard(for project: ProjectDocument) -> some View {
        let startSeconds = project.scheduleSettings.shootStartMinutes * 60
        let endSeconds = startSeconds + project.scheduleSettings.setupDurationSeconds

        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Start")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LakaiTheme.ink)
                Text(LakaiFormatters.timeString(from: startSeconds))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LakaiTheme.ink)
            }
            .frame(width: 84, alignment: .topLeading)
            .padding(8)
            .background(LakaiTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LakaiTheme.panelBorder, lineWidth: 1))

            HStack(spacing: 12) {
                Text("Setup")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LakaiTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LakaiTheme.accentSoft)
                    .clipShape(Capsule())

                TextField("Bezeichnung", text: Binding(
                    get: { appState.activeProject?.scheduleSettings.setupTitle ?? "Setup" },
                    set: { appState.updateSetupTitle($0) }
                ))
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(LakaiTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(LakaiTheme.ink)
                .font(.system(size: 13, weight: .medium))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dauer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(LakaiTheme.ink)

                    TextField("0:15", text: Binding(
                        get: {
                            if setupDurationDraft.isEmpty {
                                return LakaiFormatters.durationString(from: project.scheduleSettings.setupDurationSeconds)
                            }
                            return setupDurationDraft
                        },
                        set: { value in
                            setupDurationDraft = value
                            appState.updateSetupDuration(value)
                        }
                    ))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(LakaiTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(LakaiTheme.ink)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 96)
                }

                Spacer(minLength: 0)

                Text("Ende: \(LakaiFormatters.timeString(from: endSeconds))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LakaiTheme.ink)
            }
            .padding(12)
            .background(LakaiTheme.panel.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(LakaiTheme.panelBorder, lineWidth: 1))
        }
    }

    private func scheduleShotCard(for block: ScheduleBlock, shot: Shot, entry: CalculatedScheduleEntry, isLastBlock: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            scheduleTimeRail(for: entry)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("#\(entry.shotNumber ?? 0)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LakaiTheme.ink)

                        Text(shot.size.title)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LakaiTheme.accentSoft)
                            .clipShape(Capsule())

                        Spacer(minLength: 0)

                        if isLastBlock {
                            Text("Wrap")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(LakaiTheme.mutedInk)
                        }
                    }

                    Text(shot.descriptionText.isEmpty ? "Keine Beschreibung" : shot.descriptionText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LakaiTheme.ink)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !shot.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(shot.notes)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(LakaiTheme.mutedInk)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(alignment: .bottom, spacing: 10) {
                        labeledField(title: "Setup", text: Binding(
                            get: { scheduleSetupDrafts[shot.id, default: LakaiFormatters.durationString(from: shot.setupSeconds)] },
                            set: { value in
                                scheduleSetupDrafts[shot.id] = value
                                appState.updateShotSetup(shot.id, text: value)
                            }
                        ), width: 78)

                        labeledField(title: "Dauer", text: Binding(
                            get: { scheduleDurationDrafts[shot.id, default: LakaiFormatters.durationString(from: shot.durationSeconds)] },
                            set: { value in
                                scheduleDurationDrafts[shot.id] = value
                                appState.updateShotDuration(shot.id, text: value)
                            }
                        ), width: 78)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notizen")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(LakaiTheme.mutedInk)

                            TextField("Notizen", text: Binding(
                                get: { appState.activeProject?.scheduleBlock(with: block.id)?.scheduleNotes ?? "" },
                                set: { appState.updateScheduleNotes(block.id, text: $0) }
                            ))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(LakaiTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(LakaiTheme.ink)
                            .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                scheduleImageView(for: shot)
            }
            .padding(12)
            .background(LakaiTheme.panel.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(LakaiTheme.panelBorder, lineWidth: 1))
        }
        .scaleEffect(draggedScheduleBlockID == entry.id ? 1.01 : 1)
        .overlay(reorderCardOverlay(isDragged: draggedScheduleBlockID == entry.id))
        .zIndex(draggedScheduleBlockID == entry.id ? 2 : 0)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: draggedScheduleBlockID)
        .onDrag {
            draggedScheduleBlockID = entry.id
            return NSItemProvider(object: entry.id.uuidString as NSString)
        } preview: {
            dragPreviewPlaceholder
        }
        .onDrop(
            of: [UTType.text],
            delegate: ReorderDropDelegate(
                itemID: entry.id,
                orderedIDsProvider: { appState.activeProject?.orderedScheduleBlocks.map(\.id) ?? [] },
                draggedID: $draggedScheduleBlockID,
                insertAfterTarget: true,
                onMove: { from, to in
                    appState.moveItemLive(in: .schedule, from: from, to: to)
                }
            )
        )
    }

    private func scheduleTimeRail(for entry: CalculatedScheduleEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Setup")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LakaiTheme.mutedInk)
                Text(entry.setupStart.map(LakaiFormatters.timeString(from:)) ?? "-")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LakaiTheme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(LakaiTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LakaiTheme.panelBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text("Dreh")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LakaiTheme.mutedInk)
                Text(LakaiFormatters.timeString(from: entry.startTime))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LakaiTheme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(LakaiTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LakaiTheme.panelBorder, lineWidth: 1))
        }
        .frame(width: 84, alignment: .topLeading)
    }

    private func pauseCard(for block: ScheduleBlock, entry: CalculatedScheduleEntry?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            pauseTimeRail(for: entry)

            HStack(spacing: 12) {
                Text("Pause")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LakaiTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LakaiTheme.accentSoft)
                    .clipShape(Capsule())

                TextField("Bezeichnung", text: Binding(
                    get: { appState.activeProject?.scheduleBlock(with: block.id)?.title ?? "Pause" },
                    set: { appState.updatePauseTitle(block.id, text: $0) }
                ))
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(LakaiTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(LakaiTheme.ink)
                .font(.system(size: 13, weight: .medium))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dauer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(LakaiTheme.mutedInk)

                    TextField("0:15", text: Binding(
                        get: { pauseDurationDrafts[block.id, default: LakaiFormatters.durationString(from: block.durationSeconds)] },
                        set: { value in
                            pauseDurationDrafts[block.id] = value
                            appState.updatePauseDuration(block.id, text: value)
                        }
                    ))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(LakaiTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(LakaiTheme.ink)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 96)
                }

                Spacer(minLength: 0)

                Button {
                    appState.deleteScheduleBlock(block.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .background(LakaiTheme.accentSoft)
                .clipShape(Circle())
            }
            .padding(12)
            .background(LakaiTheme.panel.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(LakaiTheme.panelBorder, lineWidth: 1))
        }
        .scaleEffect(draggedScheduleBlockID == block.id ? 1.01 : 1)
        .overlay(reorderCardOverlay(isDragged: draggedScheduleBlockID == block.id))
        .zIndex(draggedScheduleBlockID == block.id ? 2 : 0)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: draggedScheduleBlockID)
        .onDrag {
            draggedScheduleBlockID = block.id
            return NSItemProvider(object: block.id.uuidString as NSString)
        } preview: {
            dragPreviewPlaceholder
        }
        .onDrop(
            of: [UTType.text],
            delegate: ReorderDropDelegate(
                itemID: block.id,
                orderedIDsProvider: { appState.activeProject?.orderedScheduleBlocks.map(\.id) ?? [] },
                draggedID: $draggedScheduleBlockID,
                insertAfterTarget: true,
                onMove: { from, to in
                    appState.moveItemLive(in: .schedule, from: from, to: to)
                }
            )
        )
    }

    private func pauseTimeRail(for entry: CalculatedScheduleEntry?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Start")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LakaiTheme.mutedInk)
            Text(entry.map { LakaiFormatters.timeString(from: $0.startTime) } ?? "-")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LakaiTheme.ink)
        }
        .frame(width: 84, alignment: .topLeading)
        .padding(8)
        .background(LakaiTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LakaiTheme.panelBorder, lineWidth: 1))
    }

    private func scheduleImageView(for shot: Shot) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LakaiTheme.canvasAlt.opacity(0.75))

            if let imageURL = appState.imageURL(for: shot),
               let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 144, height: 84)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(LakaiTheme.mutedInk)
            }
        }
        .frame(width: 144, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LakaiTheme.panelBorder, lineWidth: 1))
    }

    private func labeledField(title: String, text: Binding<String>, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LakaiTheme.ink)

            TextField(title, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(LakaiTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(LakaiTheme.ink)
                .font(.system(size: 11, weight: .medium))
                .frame(width: width)
        }
    }

    private func compactField(_ title: String, value: String, onChange: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(LakaiTheme.ink)

            TextField(title, text: Binding(get: { value }, set: onChange))
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(LakaiTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(LakaiTheme.ink)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 118)
        }
    }

    private func compactDateButton<Content: View>(title: String, value: String, isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(LakaiTheme.mutedInk)

            Button(value) {
                isPresented.wrappedValue.toggle()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundStyle(LakaiTheme.ink)
            .popover(isPresented: isPresented, arrowEdge: .bottom) {
                content()
            }
        }
    }

    private func logoControls(kind: LogoKind, imageURL: URL?) -> some View {
        HStack(spacing: 6) {
            if let imageURL, let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(LakaiTheme.panelBorder, lineWidth: 1))
            }

            Button(kind == .client ? "Kundenlogo" : "Produktionslogo") {
                appState.importLogo(kind)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundStyle(LakaiTheme.ink)

            if imageURL != nil {
                Button("x") {
                    appState.clearLogo(kind)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(LakaiTheme.ink)
            }
        }
    }

    private func versionPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(LakaiTheme.mutedInk)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LakaiTheme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(LakaiTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metaPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(LakaiTheme.mutedInk)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LakaiTheme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(LakaiTheme.panelElevated.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LakaiTheme.panelBorder, lineWidth: 1))
    }

    private func date(fromMinutes minutes: Int, on date: Date) -> Date {
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: minutes, to: baseDate) ?? date
    }

    private func syncDrafts(_ project: ProjectDocument) {
        scheduleSetupDrafts = Dictionary(uniqueKeysWithValues: project.shots.map { ($0.id, LakaiFormatters.durationString(from: $0.setupSeconds)) })
        scheduleDurationDrafts = Dictionary(uniqueKeysWithValues: project.shots.map { ($0.id, LakaiFormatters.durationString(from: $0.durationSeconds)) })
        pauseDurationDrafts = Dictionary(uniqueKeysWithValues: project.orderedScheduleBlocks.filter { $0.kind == .pause }.map { ($0.id, LakaiFormatters.durationString(from: $0.durationSeconds)) })
        setupDurationDraft = LakaiFormatters.durationString(from: project.scheduleSettings.setupDurationSeconds)
    }

    private func resetDragState() {
        appState.commitPendingReorderChanges()
        draggedShotID = nil
        draggedScheduleBlockID = nil
    }

    private func installDragStateResetMonitor() {
        guard localMouseUpMonitor == nil else {
            return
        }

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { event in
            resetDragState()
            return event
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
            DispatchQueue.main.async {
                resetDragState()
            }
        }
    }

    private func removeDragStateResetMonitor() {
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }

        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
    }

    private func reorderCardOverlay(isDragged: Bool) -> some View {
        let lineWidth: CGFloat = isDragged ? 2.0 : 0

        return RoundedRectangle(cornerRadius: 18)
            .stroke(LakaiTheme.ink.opacity(isDragged ? 0.95 : 0), lineWidth: lineWidth)
    }

    private var dragPreviewPlaceholder: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.clear)
            .frame(width: 2, height: 2)
    }

    private var dropGapView: some View {
        Color.clear
            .frame(height: dropGapHeight)
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let itemID: UUID
    let orderedIDsProvider: () -> [UUID]
    @Binding var draggedID: UUID?
    let insertAfterTarget: Bool
    let onMove: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID,
              draggedID != itemID else {
            return
        }

        let orderedIDs = orderedIDsProvider()

        guard let fromIndex = orderedIDs.firstIndex(of: draggedID),
              let toIndex = orderedIDs.firstIndex(of: itemID),
              fromIndex != toIndex else {
            return
        }

        let destination = insertAfterTarget ? toIndex + 1 : toIndex

        // Ignore no-op moves to avoid jitter while hovering nearby cells.
        if fromIndex == destination || fromIndex + 1 == destination {
            return
        }

        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.88)) {
            onMove(fromIndex, destination)
        }
    }

    func dropExited(info: DropInfo) {
        return
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}