# Lakai Architecture

## Stack

- SwiftUI for the macOS user interface.
- AppKit where native macOS dialogs, image handling, and PDF generation are needed.
- Foundation XML APIs for explicit project serialization.
- FileManager and Process for folder management and ZIP workflows.

## Top-Level Structure

- `LakaiApp`: application entry and window group.
- `AppState`: top-level observable state for the project library and active project.
- `Models`: pure project data definitions.
- `Services`: persistence, PDF export, ZIP handling, image import, and scheduling logic.
- `Views`: overview, script editor, shotlist, schedule, and supporting editor screens.
- `Components`: reusable UI blocks like shot cards, schedule rows, and the script text editor.
- `Utilities`: shared helpers for date formatting, colors, and small extensions.

## Data Flow

1. The overview loads project summaries from the Lakai projects directory.
2. Opening or creating a project loads an XML file into `ProjectDocument`.
3. The UI edits the in-memory document via bindings.
4. Script edits are parsed into shots, and shotlist edits regenerate the script text.
5. Persistence writes the full XML plus related assets back to the project folder.
6. Exports read from the current in-memory document and write PDF files to a user-chosen destination.
7. Successful export increments the matching version counter and persists the project again.

### Interaction Performance Note
- Schedule and shotlist drag-and-drop reorder commits are applied on drop, not continuously on hover enter.
- This keeps reorder feedback stable and avoids repeated persistence churn during pointer movement.
- Drop insertion now targets the divider shown below the hovered card so visual indicator and final position stay aligned.
- The drop-divider gap uses a larger centered insertion lane with eased open/close transitions and spring-based snap animation.

## Core Models

### ProjectDocument
- Project metadata
- Storyboard version counter
- Schedule version counter
- Shotlist order
- Separate schedule block order including shots and pause blocks
- Script text representation
- Crew data
- Timing configuration
- Asset references

### Shot
- Stable identifier
- Shot size tag
- Description
- Notes
- Optional image file name
- Per-shot setup duration
- Shot duration

### ScheduleBlock
- Stable identifier
- Block kind: shot or pause
- Optional linked shot id
- Custom pause title
- Pause duration
- Schedule-specific notes for shot blocks

### ScheduleSettings
- Shoot date
- Shoot start time

### CrewInfo
- Director
- 1st AD
- Producer
- Client
- DoP
- Optional client logo file name
- Optional production logo file name

## XML Format Strategy

- One human-readable XML file per project.
- Asset references are stored as relative file names only.
- Order arrays are stored explicitly so shotlist and schedule stay independent, and the schedule can include pause blocks.
- Script text is stored explicitly alongside the structured shot data so the freeform editor can round-trip.
- Durations are serialized as integer seconds to avoid locale parsing issues.

## Scheduling Engine

- The engine reads the schedule order and timing settings.
- It starts with the shoot start time.
- It starts with a fixed setup block duration from schedule settings, then continues with ordered schedule blocks.
- For each schedule block it calculates:
  - setup start
  - block start
  - block end
  - next available time
- Shots use their own setup and duration values.
- Pause blocks have no setup and contribute only their own duration.

## Script Sync

- `ScriptSyncService` converts freeform script text into structured shots.
- Shot markers begin new shots and everything before the first marker is ignored.
- Recognized leading English shot size keywords are stripped from the description and mapped onto `ShotSize`.
- Subsequent non-marker lines are stored as shot notes.
- Structured shots are composed back into a deterministic script text format whenever the shotlist changes outside the script editor.

## Export Design

### Storyboard PDF
- Header with project title, export date, storyboard version, and shot count.
- Landscape A4 white table layout with print-first styling.
- Dynamic row height from wrapped text and image aspect ratio.
- Images rendered in dedicated storyboard cells using direct asset decoding.

### Schedule PDF
- Header with project title, export date, schedule version, and crew details.
- Summary block for shoot date and shoot start.
- White table timeline with wrapped description and notes columns.
- Dynamic row heights prevent clipped text in dense schedules.
- Production and client logos are rendered in the schedule header when logo assets are present.
- The exported table omits a dedicated type column; pause rows are marked in the shot column and shaded lightly.
- Empty schedule values are emitted as empty table cells rather than placeholder dashes.

### Export Flow
- `NSSavePanel` chooses the destination for both storyboard and schedule PDFs.
- PDF rendering uses direct Core Graphics table drawing with CoreText line wrapping for crisp text output.
- Page breaks happen only between complete rows so no row is split at the page boundary.
- Text drawing uses native PDF coordinates so output remains correctly oriented.

## Storage Layout

Each project folder contains:

- `project.xml`
- `Images/`
- `Logos/`

Project archive import and export operate on the full project folder.
The visible archive extension is `.lak`; the container format remains ZIP-compatible internally.

## Design Principles

- Use stable identifiers for shots and derive visible numbering from order.
- Keep business logic in services rather than SwiftUI views.
- Keep XML and PDF output deterministic and debuggable.
- Favor readable code over indirection because the project is intended to be edited with low context cost.
- Keep documentation in sync with code changes, especially when models, storage layout, export behavior, or UI flows change.
- Keep UI tokens centralized in `LakaiTheme`; dark surfaces and high-contrast text are the default visual baseline.

## Delivery Rule

- A compiled `.app` test build must be generated at the end of each implementation round.
- The current delivery location for manual testing is `Build/Lakai.app` in the repository root.