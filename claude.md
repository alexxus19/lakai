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

### PDF Table Configuration (Non-Negotiable)

- PDF pages use a white background with print-first black text and gray table lines.
- PDF rendering uses direct Core Graphics table drawing plus CoreText line wrapping.
- Text orientation is normal left-to-right; no mirrored or flipped text output is allowed.
- Storyboard and schedule exports both use a structured table with fixed headers and bordered cells.
- Row height is dynamic, derived from wrapped text height and image aspect fit needs.
- Page breaks are row-safe: a row is only placed if it fits fully; rows must never be cut at the page bottom.
- Empty values are rendered as empty cells (no dash placeholders).
- Storyboard table columns are: `Shot`, `Groesse`, `Beschreibung`, `Notizen`, `Storyboard`.
- Schedule table columns are: `Shot`, `Setup`, `Start`, `Ende`, `Groesse`, `Beschreibung`, `Shot-Notizen`, `Plan-Notizen`, `Bild`.
- The schedule `Typ` column is intentionally removed; reclaimed width is assigned to the `Bild` column.
- Schedule rows include a fixed first `Setup` row before all other entries.
- Pause rows render `Pause` in the `Shot` column and the full row is lightly gray tinted.
- Image cells use aspect-fit rendering with high interpolation quality.
- Schedule header logos (production and client) are rendered only when actual logo assets exist.
- No placeholder border/frame is drawn for missing logos in the schedule PDF header.

### Reorder Interaction (Non-Negotiable)

- Reordering in shotlist and schedule is live while dragging; list order updates on hover before drop.
- The dragged card is the only highlighted card during reorder.
- No secondary target-card highlight is shown during reorder.
- The schedule has a valid insertion position between the fixed `Setup` card and the first reorderable block.
- Drag cancellation or dropping outside valid targets must always clear drag visual state.
- Reorder interaction must be optimized for responsiveness; persistence is committed once at drag end, not on every hover move.

### Build & Deployment (Non-Negotiable)

- After each completed implementation pass, a compiled test build of the app must be produced inside the repository directory so it can be opened directly for manual testing.
- The build output must be placed in `/Build/Lakai.app` so users can test the latest changes without rebuilding via Xcode.

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
- Shot numbers are derived from the current order; optional shots use "OPT_" prefix with independent counting.
- Each shot has:
  - Shot number (or optional marker)
  - Shot size tag from a predefined dropdown using written German shot size names
  - Description
  - One-line notes or camera move field
  - Optional storyboard image imported from disk
  - Optional background color (6 pastel options)
  - Optional flag that affects visibility and timing
- A permanent 16:9 storyboard image slot on the right side of the card, with hover actions for replacing or removing the image.
- Right-click context menu on shots provides: toggle optional status, color picker, duplicate function, and delete action.
- Optional shots display at 30% opacity for visual distinction.
- Storyboard PDF export uses the current project state with shot background colors applied to table rows.
- All shot properties (background color, optional status) are XML-persisted.

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
- A fixed non-reorderable `Setup` block appears at the top of every schedule with editable title and duration.
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
- Optional shots do not contribute to timing; schedule times remain unchanged regardless of optional shot presence.
- In the shooting schedule, shot description and shot annotations are shown compactly as read-only card content.
- Schedule shot cards provide a separate editable `Notizen` field for schedule-specific notes.
- Optional shots display at 30% opacity and hide time rails (setup/shoot durations) to indicate they are not scheduled.
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

### PDF Export Quality & Print Layout Refresh
- PDF pages now render as high-contrast black-on-white table documents optimized for print and low ink usage
- Export rows use dynamic height based on real wrapped text and image aspect ratio, avoiding clipped card text and hard truncation
- Page breaks now happen only when a complete row fits, preventing row content from being cut at the page bottom
- Storyboard and schedule image cells now use robust asset decoding and high-quality interpolation for reliable image embedding

### Drag-and-Drop Insert Accuracy
- Shot and schedule reorder drops now insert exactly at the visual divider position (below the hovered card)
- The visible divider gap has been increased to make the insertion target clearer during drag operations

### Readability Hardening on Dark UI
- Controls that previously rendered dark text on dark backgrounds (for example `Übersicht` and compact date controls) now force light foreground text
- The Lakai title on the overview and bordered header actions now use explicit high-contrast light text styling

### Reorder Interaction Smoothness
- The visual insert gap below a hovered card was increased to roughly double height, with the divider centered in the gap
- Gap open/close transitions and drop snap animations were tuned for smoother motion and less perceived lag

### PDF Header & Text Orientation Fix
- PDF body text orientation was corrected so all table text renders in normal left-to-right direction
- Schedule PDF headers now include production and client logos when available in the project assets

### Schedule Setup Block & PDF Table Tuning
- The schedule now always starts with a dedicated, non-draggable `Setup` block in app and PDF exports
- In schedule PDFs, the `Typ` column was removed and its width reassigned to the image column
- Pause entries render `Pause` in the shot column and the full pause row uses a light gray background tint
- Empty values in schedule PDFs are rendered as empty cells (no dash placeholders)
- Logo header rendering in schedule PDFs no longer draws placeholder borders around logo slots

### Reorder Performance & Drag UX Hardening
- Shotlist and schedule reorder now use lighter hover-state updates to reduce jitter and improve drag responsiveness
- The old divider-line insertion marker was replaced by gap-based insertion with card highlight outlines
- Schedule reorder now includes a dedicated insertion zone between the fixed `Setup` block and the first reorderable block
- Drag state is reset robustly on mouse-up to avoid cards remaining in a stale dragged visual state after cancelled/outside drops
- Section headers and shot size selector controls were hardened to explicit high-contrast light text on dark surfaces

### Live Reorder Interaction (Current Pass)
- Reordering now commits live on hover while dragging, so list order updates continuously before drop
- The dragged card is the only highlighted element; secondary target-card highlighting was removed
- Drop finalization now only clears drag state (no extra reorder on drop), preventing duplicate movement at release
- Reorder writes are now deferred: list movement is in-memory during drag, then persisted once when drag ends

### Reorder Rendering Performance Pass
- Shotlist, schedule thumbnails, and header logo images now use cached asset loading instead of synchronous per-render `NSImage(contentsOf:)` decoding
- Reorder interactions no longer trigger draft resynchronization on every `updatedAt` change in the workspace root
- Live reorder updates no longer touch `updatedAt` while dragging; timestamp and persistence are finalized at drag end

### Cached Image Reliability Pass
- Cached asset image loading now keys by normalized file path and refreshes with `task(id:)` so images reappear reliably after mode/page switches
- Image tiles now show explicit loading placeholders instead of blank empty content while assets resolve

### Project Archive Extension Hardening
- Project archive save/open dialogs now target a dedicated `.lak` file type so exports no longer get `.lak.zip`
- Archive internals remain ZIP-compatible while the visible extension stays strictly `.lak`

### Shot Coloring, Optionality & Duplication (Current Pass)
- Right-click context menu on shot cards provides three new options: Optional toggle, color picker, and duplicate
- Color picker displays 6 pastel color circles (mint, peach, sky, rose, cream, lavender) plus a clear button
- Shot background colors persist in XML and are reflected in both app UI (with reduced opacity) and PDF exports
- Optional shots display at 30% opacity in shotlist and schedule views for visual distinction
- Optional shot numbering uses "OPT_" prefix with separate counting (e.g., "1", "2", "OPT_1", "3", "OPT_2")
- Optional shots are excluded from timing calculations in the schedule; times do not shift based on optional content
- Schedule cards hide time rails (Setup/Dreh durations) when shot is marked optional
- Shot duplication preserves all properties and automatically creates corresponding schedule block
- Pause blocks also support background coloring via context menu (when implemented)
- All new properties (isOptional, backgroundColor) are XML-persisted and survive project open/close cycles

### macOS Context Menu Compatibility Fix
- Shot card right-click menus now use a native macOS-compatible context menu structure built only from supported menu items and submenus
- The previous custom layout-based menu content prevented the context menu from appearing on secondary click in SwiftUI on macOS

### Shot Card Layout Compaction Pass
- Shot number and shot size selector now live in a dedicated left-side metadata column, with the shot number above the size control
- Delete was removed from the inline card chrome and is now available only from the shot card context menu
- Shot description and notes fields were tightened vertically so the overall card can render more compactly

### Shot Card UI Refinements (Current Pass)
- Shot number display size increased 20% with bold weight for better visual prominence
- Size selector menu now displays the currently selected size in the label (not just "Groesse")
- Size selector duplicate arrow removed; menu shows only single native dropdown indicator
- Color menu options now display human-readable color names (Mint, Peach, Sky, Rose, Cream, Lavender) with inline color preview circles
- Context menu delete action available on all non-editable card surfaces for reliable rightclick activation

### Script Editor Readability Update
- In `Skript` mode, the editor text and insertion cursor are now forced to white for clear contrast on dark backgrounds

### Readability Hardening on Dark UI
- Script syntax styling now keeps base shot lines in white and keyword highlights in softened white so formatted script text no longer falls back to dark system label colors
- Shot size selector value text is now explicitly white for stable contrast on dark card controls
- Shot color context-menu labels now force primary menu text color while keeping colored dot previews, so both name and swatch remain visible

### Selector & Menu Reliability Pass
- Shot size selection in cards now uses a custom app-styled popover list, ensuring the selected size label remains visible in white on dark controls
- Color submenu entries now use native label rows with a tinted circle symbol and explicit color names for stable visibility in the macOS context menu

## Acceptance Baseline

- A new project can be created from the overview.
- Shots can be added, reordered, edited, tagged, and illustrated.
- Shots can be marked optional, colored, or duplicated via right-click context menu.
- Optional shots render at reduced opacity and exclude from timing calculations.
- Shot backgrounds and optional status persist in XML and appear in PDF exports.
- Script text can generate and regenerate the same shotlist structure.
- The shooting schedule can reorder the same shots independently.
- Schedule timing updates when durations or lunch settings change.
- Storyboard and schedule can both be exported as PDFs.
- Version counters increment on export.
- Projects can be saved as folders and exchanged as ZIP files.