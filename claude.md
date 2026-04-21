# Lakai Scope Guard

## Product Goal

Lakai is a native macOS directing tool for creating, organizing, versioning, and exporting shotlists and shooting schedules.

## Non-Negotiable Scope

1. The app name is Lakai.
2. The app is a native macOS app built with SwiftUI.
3. The app supports project overview, script editing, shotlist editing, shooting schedule planning, PDF export, XML persistence, image attachment, and ZIP import/export.
4. Shotlist and shooting schedule order are intentionally separated.
5. Exported PDFs always include version number and export date.
6. Exporting a storyboard PDF increments the storyboard version counter for that project.
7. Exporting a shooting schedule PDF increments the shooting schedule version counter for that project.
8. Project data is stored in XML plus a project folder that contains imported images and logos.
9. Projects can be packaged and restored as ZIP files.

## Functional Requirements

### Overview
- Show existing projects in a clean dashboard.
- Provide a prominent action for creating a new project.
- Opening a project lands in the shotlist area.

### Shotlist Area
- Editable project title.
- Visible storyboard version counter.
- Single-column board of shot cards.
- New shots can be added and removed.
- Cards can be reordered by drag and drop.
- Shot numbers are derived from the current order.
- Each shot has:
  - Shot number
  - Shot size tag from a predefined dropdown using written German shot size names
  - Description
  - One-line notes or camera move field
  - Optional storyboard image imported from disk
- A permanent 16:9 storyboard image slot on the right side of the card, with hover actions for replacing or removing the image.
- Storyboard PDF export uses the current project state.

### Script Area
- The mode switch includes `Skript`, `Shotlist`, and `Drehplan`.
- A freeform script editor is available as a third workspace mode.
- Lines before the first shot marker are ignored.
- New shots are recognized from lines beginning with markers like `•`, `#`, `-`, `*`, or bracketed markers like `[ ... ]`.
- Text directly after the marker becomes the shot description.
- Following lines until the next marker become the shot notes.
- English shot size phrases at the start of a shot line are recognized and mapped onto Lakai shot sizes.
- Script edits automatically rebuild the shotlist and schedule shot blocks.
- Shotlist edits automatically regenerate the script text.

### Shooting Schedule Area
- View switch uses a slider-style control.
- Each third of the slider control is fully clickable (`Skript`, `Shotlist`, `Drehplan`), not only the text label.
- No new shots are created here.
- Existing shots can be reordered independently from the shotlist.
- Pause blocks can be inserted, named, timed, and reordered alongside shots.
- Pause blocks show a compact left-side `Start` time box only; redundant end/duration summary pills are not shown below the card.
- User can define:
  - Client logo
  - Production company logo
  - Director
  - 1st AD
  - Producer
  - Client
  - DoP
  - Shoot date
  - Shoot start time
  - Per-shot setup duration
  - Per-shot duration
- Schedule timing is calculated based on the order, start time, per-shot setup, shot duration, and pause blocks.
- In the shooting schedule, shot description and shot annotations are shown compactly as read-only card content.
- Schedule shot cards provide a separate editable `Notizen` field for schedule-specific notes.
- Shooting schedule PDF export uses the schedule order and increments the schedule version.

### Persistence and File Exchange
- Every project lives in its own folder.
- Renaming the project also renames the project folder to a matching safe folder name.
- XML is the primary editable data file.
- Imported storyboard and logo images are copied into the project folder.
- PDF export always asks for a destination with a native save panel instead of writing into the project folder.
- Projects support ZIP export and ZIP import.

## Out of Scope

- Multi-user collaboration
- Cloud sync
- Calendar integration
- Video playback or timeline editing
- iPhone or iPad support
- Automatic OCR or AI tagging

## UX Direction

- Modern macOS interface with clear information density.
- Modern dark editorial visual style with strong contrast and high text legibility.
- Strong hierarchy for project title, version, and export actions.
- Compact and neatly structured shot cards, with an especially dense shooting schedule layout.

## Implementation Rules

- Keep code comments useful and focused on intent.
- Prefer small, composable views and service types.
- Keep XML structure explicit and easy to inspect manually.
- Avoid hidden magic and unnecessary abstractions.
- Preserve a separation between data model, persistence, export, and UI.
- **Every functional, structural, or UX change must be reflected in the documentation files so the written scope and implementation notes stay current. This is a non-negotiable requirement.**
- After each completed implementation pass, a compiled test build of the app must be produced inside the repository directory so it can be opened directly for manual testing.
- Follow Apple Human Interface Guidelines (HIG) for macOS design patterns, colors, typography, and interaction models.

## Design System

- **Typography & Colors**: Follow macOS HIG standards. Use system fonts at recommended sizes. Use high-contrast light text on dark surfaces for legibility.
- **Input Fields**: Input fields use dark elevated fills with bright foreground text and clear border contrast.
- **Cards**: Dark elevated panels with subtle cool-toned borders for visual separation.
- **Visual Hierarchy**: Bold titles > regular body text > muted secondary text using LakaiTheme color stops.

## Recent Changes (Session log)

### PDF Export Pipeline Reconstruction
- Replaced NSHostingView+NSGraphicsContext bitmap approach with SwiftUI `ImageRenderer` API
- Reason: Previous approach generated blank pages, upside-down content, and failed image embedding
- Status: Now uses `ImageRenderer.nsImage` for consistent rendering

### Drag-and-Drop Visual Feedback
- Added hover state tracking (`hoveredDropTargetID` / `hoveredScheduleDropTargetID`)
- Black divider line appears under target card during drag
- `ReorderDropDelegate` updated to manage hover state via `dropEntered()` / `dropExited()` callbacks

### Project Archiving Naming
- Changed from generic "ZIP" terminology to "Projekt" (German)
- Export button label: "Projekt exportieren" 
- Import button label: "Projekt importieren"
- File extension: `.lak` (internally ZIP, visible as `.lak` to users)

### Script Mode Enhancements
- Parser handles checkbox format (`- [ ]`), leading numbers, multiple shot size keywords
- German and English shot size recognition (Halbnah, Nahaufnahme, Close, Wide, Medium Close, Medium Shot)
- Regex-based leading label detection for ALTERNATIV: markers
- Bidirectional sync: script edits update shotlist; shotlist edits regenerate script text

### Schedule Layout Improvements
- Left-side time rail added to schedule cards showing Setup time and Dreh (shoot) time
- Times calculated dynamically based on order, durations, and pause blocks
- Schedule-specific notes field separate from shot notes (persisted in XML)

### UI Polish
- Black-and-white editorial color palette
- Drag opacity reduced to 0.3 for clearer visual feedback
- Expanded project deletion from overview (trash icon button)

### Schedule Interaction & Theme Refresh
- Pause blocks now follow the schedule card rhythm with a compact left-side `Start` rail and no extra end/duration pill row
- `Setup`/`Dreh` left rail boxes in schedule cards are narrower and top-aligned with card content
- Mode switch segments are fully clickable across the complete third-width area
- Drag-and-drop reorder now commits on drop (instead of during every hover step) to reduce UI jitter and improve responsiveness
- Global color system refreshed to a modern dark palette with improved text contrast

## Acceptance Baseline

- A new project can be created from the overview.
- Shots can be added, reordered, edited, tagged, and illustrated.
- Script text can generate and regenerate the same shotlist structure.
- The shooting schedule can reorder the same shots independently.
- Schedule timing updates when durations or lunch settings change.
- Storyboard and schedule can both be exported as PDFs.
- Version counters increment on export.
- Projects can be saved as folders and exchanged as ZIP files.