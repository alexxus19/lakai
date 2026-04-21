import Foundation

struct ScheduleCalculator {
    func buildComputation(for project: ProjectDocument) -> ScheduleComputation {
        let startOfDay = project.scheduleSettings.shootStartMinutes * 60
        var currentTime = startOfDay
        var entries: [CalculatedScheduleEntry] = []
        for block in project.orderedScheduleBlocks {
            switch block.kind {
            case .shot:
                guard let shotID = block.shotID, let shot = project.shot(with: shotID) else {
                    continue
                }

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
            }
        }

        return ScheduleComputation(entries: entries)
    }
}