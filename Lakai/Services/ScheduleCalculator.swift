import Foundation

struct ScheduleCalculator {
    func buildComputation(for project: ProjectDocument) -> ScheduleComputation {
        let startOfDay = project.scheduleSettings.shootStartMinutes * 60
        var currentTime = startOfDay + max(project.scheduleSettings.setupDurationSeconds, 0)
        var entries: [CalculatedScheduleEntry] = []
        var isFirstShotInSegment = true

        for block in project.orderedScheduleBlocks {
            switch block.kind {
            case .shot:
                guard let shotID = block.shotID, let shot = project.shot(with: shotID) else {
                    continue
                }

                if shot.isOptional {
                    // Optional shots don't contribute to timing calculation
                    entries.append(
                        CalculatedScheduleEntry(
                            block: block,
                            shot: shot,
                            shotNumber: project.shotNumber(for: shotID),
                            setupStart: nil,
                            startTime: currentTime,
                            endTime: currentTime,
                            nextAvailable: currentTime
                        )
                    )
                } else if isFirstShotInSegment {
                    // First shot of the day: no per-shot setup, starts immediately after day setup
                    let startTime = currentTime
                    let endTime = startTime + shot.durationSeconds
                    entries.append(
                        CalculatedScheduleEntry(
                            block: block,
                            shot: shot,
                            shotNumber: project.shotNumber(for: shotID),
                            setupStart: nil,
                            startTime: startTime,
                            endTime: endTime,
                            nextAvailable: endTime
                        )
                    )
                    currentTime = endTime
                    isFirstShotInSegment = false
                } else {
                    let setupStart = currentTime
                    let startTime = currentTime + shot.setupSeconds
                    let endTime = startTime + shot.durationSeconds
                    let nextAvailable = endTime

                    entries.append(
                        CalculatedScheduleEntry(
                            block: block,
                            shot: shot,
                            shotNumber: project.shotNumber(for: shotID),
                            setupStart: setupStart,
                            startTime: startTime,
                            endTime: endTime,
                            nextAvailable: nextAvailable
                        )
                    )

                    currentTime = nextAvailable
                }
            case .pause:
                let endTime = currentTime + block.durationSeconds
                entries.append(
                    CalculatedScheduleEntry(
                        block: block,
                        shot: nil,
                        shotNumber: nil,
                        setupStart: nil,
                        startTime: currentTime,
                        endTime: endTime,
                        nextAvailable: endTime
                    )
                )
                currentTime = endTime

            case .dayHeader:
                // New day: reset timing with day start + its own setup duration
                let dayStart = block.dayStartMinutes * 60
                currentTime = dayStart + block.daySetupDurationSeconds
                isFirstShotInSegment = true
                entries.append(
                    CalculatedScheduleEntry(
                        block: block,
                        shot: nil,
                        shotNumber: nil,
                        setupStart: nil,
                        startTime: dayStart,
                        endTime: dayStart,
                        nextAvailable: dayStart
                    )
                )
            }
        }

        return ScheduleComputation(entries: entries)
    }
}