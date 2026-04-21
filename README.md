# Lakai

**Native macOS shotlist & shooting schedule manager for film and TV production**

![macOS](https://img.shields.io/badge/macOS-12%2B-000000?style=flat-square) ![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-0A84FF?style=flat-square) ![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## Overview

Lakai is a purpose-built macOS application that bridges creative script development with production logistics. Film and television professionals use Lakai to **create, organize, version, and export** shotlists and shooting schedules through an integrated workflow.

### The Problem
Production workflows typically fragment across multiple tools: scripts, spreadsheets, PDFs, and chat. Lakai reunifies this process into a single, native macOS experience where script edits automatically propagate to shooting schedules, and schedule changes intelligently recalculate timing.

### The Solution
Three integrated workspace modes—**Skript**, **Shotlist**, and **Drehplan**—work in harmony:
- Edit scripts and extract shots automatically
- Organize and illustrate shots with storyboard images
- Build independent shooting schedules with crew info and timing
- Export versioned PDFs with full metadata

---

## Key Features

- **Three Workspace Modes**
  - **Skript** – Freeform script editing with automatic shot extraction
  - **Shotlist** – Single-column storyboard with drag-and-drop reordering
  - **Drehplan** – Intelligent shooting schedule with crew, timing, and pause blocks

- **Bidirectional Sync**
  - Edit scripts → automatically regenerate shotlists
  - Edit shotlists → automatically regenerate scripts
  - Independent shot ordering for schedule vs. shotlist

- **Intelligent Scheduling**
  - Auto-calculated timing based on setup, shoot duration, and pause blocks
  - Per-shot customizable durations
  - Crew roles (Director, DoP, 1st AD, Producer, Client)
  - Client and production company logos

- **Shot Management**
  - German film terminology shot sizes (Nahaufnahme, Halbnah, etc.)
  - Storyboard images embedded per shot
  - Shot numbers derived from current order
  - Description and notes fields

- **PDF Export with Versioning**
  - Storyboard PDF (for creative review)
  - Shooting schedule PDF (for production day)
  - Automatic version incrementing
  - Export date and metadata included

- **Project Packaging**
  - ZIP-based import/export for archiving
  - Full project folder with images and metadata
  - Portable across computers and teams

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **UI Framework** | SwiftUI (macOS 12+) |
| **Native Integration** | AppKit (dialogs, PDF rendering) |
| **Data Format** | XML (human-readable, inspectable) |
| **File Management** | FileManager, ZIP archives |
| **Swift** | 5.9+ |

---

## Project Structure

```
Lakai/
├── LakaiApp.swift              # Entry point
├── Models/
│   └── ProjectModels.swift     # Core data types (Shot, ShotSize, ProjectDocument, CrewInfo)
├── Services/                   # Business logic
│   ├── AppState.swift          # Observable state management
│   ├── ProjectPersistenceService.swift
│   ├── ProjectPackagingService.swift
│   ├── PDFExportService.swift
│   ├── ScheduleCalculator.swift
│   └── ScriptSyncService.swift # Script ↔ Shotlist bidirectional parsing
├── Views/                      # UI screens
│   ├── RootView.swift
│   ├── OverviewView.swift      # Project dashboard
│   └── WorkspaceView.swift     # Integrated Skript/Shotlist/Drehplan modes
├── Components/                 # Reusable UI blocks
│   ├── ShotCardView.swift
│   └── ScriptTextEditor.swift
├── Utilities/
│   └── Theme.swift             # Dark color palette, formatters
└── Assets.xcassets/
```

### Key Services

| Service | Responsibility |
|---------|-----------------|
| **AppState** | `@MainActor` observable, project summaries, active project |
| **ProjectPersistenceService** | XML read/write, folder management |
| **ScriptSyncService** | Parse scripts, extract shots, bidirectional sync |
| **ScheduleCalculator** | Timing engine for setup/shoot durations |
| **PDFExportService** | Render and export versioned PDFs |
| **ProjectPackagingService** | ZIP import/export workflows |

---

## Getting Started

### Prerequisites
- **macOS 12.0** or later
- **Xcode 15.0** or later
- **Swift 5.9** or later

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/lakai.git
   cd lakai
   ```

2. **Open in Xcode**
   ```bash
   open Lakai.xcodeproj
   ```

3. **Build and Run**
   - Select the `Lakai` scheme
   - Press `Cmd + R` to run, or use the build script:
   ```bash
   ./Tools/build_test_app.sh
   ```
   
   The compiled app will appear at `Build/Lakai.app` for direct testing.

4. **Run the Application**
   ```bash
   open Build/Lakai.app
   ```

---

## Usage Workflow

### Creating a Project
1. From the **Overview** screen, click the "Neues Projekt" button
2. Name your project and confirm
3. Land directly in the **Shotlist** editor

### Building a Shotlist
- **Add shots** – Click the "+" button to add new shots
- **Edit shot details** – Add description, notes, shot size tag, and storyboard image
- **Reorder** – Drag and drop shots to reorder; shot numbers update automatically
- **Add images** – Click the storyboard placeholder to import 16:9 images

### Syncing from Script
1. Switch to the **Skript** tab
2. Paste or write your production script
3. Mark shots with `•`, `#`, `-`, `*`, or `[...]` markers
4. Add English or German shot sizes (e.g., "Close-up: Actor reacts")
5. Press "Aus Script generieren" to extract shots into the shotlist
6. Edit shotlist → returns to Skript mode and regenerates script text

### Building a Schedule
1. Switch to the **Drehplan** tab
2. Add crew info (Director, DoP, Client, etc.)
3. Set shoot date and start time
4. Define per-shot setup and shoot durations
5. Reorder shots independently from shotlist
6. Insert pause blocks for breaks
7. Timing auto-calculates as you adjust

### Exporting
- **Storyboard PDF** – Export current shotlist as versioned PDF (increments storyboard version)
- **Schedule PDF** – Export current schedule as versioned PDF (increments schedule version)
- **Project ZIP** – Package entire project with images for sharing or archiving

---

## Data Persistence

Lakai stores projects as self-contained folders:

```
MyProject/
├── project.xml              # All structured data (shots, crew, schedule)
├── Images/                  # Imported storyboard images
└── Logos/                   # Client and production logos
```

**XML Format:**
- Human-readable, explicitly structured
- Assets stored as relative file references
- Shot and schedule ordering kept separate
- Script text preserved for round-trip consistency

---

## Architecture Highlights

### Service-Driven Design
- **Business logic** isolated from UI views
- **Observable state** via `@MainActor` pattern
- **Deterministic persistence** – XML is inspectable and debuggable

### Bidirectional Sync
- **ScriptSyncService** parses markers (•, #, -, *, [...])
- Extracts German and English shot sizes
- Regenerates script text when shotlist changes
- Maintains shot descriptions and notes

### Intelligent Scheduling
- **ScheduleCalculator** computes timing dynamically
- Factors: shot order, setup/shoot duration, pause blocks, start time
- Updates in real-time as user adjusts parameters

### PDF Generation
- **PDFExportService** uses SwiftUI `ImageRenderer` hosted in AppKit
- Consistent rendering across display scales
- Embeds images and logo graphics
- Increments version counters post-export

---

## Documentation

- **[claude.md](claude.md)** – Product scope, functional requirements, UX direction, and design principles
- **[claude_architecture.md](claude_architecture.md)** – Deep technical documentation: data flows, XML schema, scheduling engine, design patterns
- **[CONTRIBUTING.md](CONTRIBUTING.md)** – Developer setup, contribution guidelines, PR workflow

---

## Development

### Running Tests

```bash
xcodebuild -project Lakai.xcodeproj -scheme Lakai -configuration Debug
```

### Building for Release

```bash
xcodebuild -project Lakai.xcodeproj -scheme Lakai -configuration Release
```

### Code Style

- Follow [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use small, composable views and service types
- Keep XML structure explicit and inspectable
- Avoid hidden abstractions; favor clarity

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) file for details.

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Developer environment setup
- Branch naming and commit conventions
- Pull request guidelines
- Code review process

---

## Author & Contact

Developed by **Alex Mahfoudh**

---

## Roadmap & Future Work

- [ ] User guide and video tutorials
- [ ] Keyboard shortcut customization
- [ ] Dark/light theme toggle
- [ ] Extended shot size dictionaries (French, Spanish)
- [ ] GitHub Actions for automated builds
- [ ] Release notes and CHANGELOG

---

## Support

For questions, feature requests, or bug reports, please open an [issue](https://github.com/yourusername/lakai/issues).

