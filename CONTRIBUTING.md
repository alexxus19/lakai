# Contributing to Lakai

Thank you for your interest in contributing to Lakai! This document outlines our development process, code conventions, and contribution guidelines.

---

## Developer Setup

### Prerequisites
- **macOS 12.0** or later
- **Xcode 15.0** or later (install from App Store or Apple Developer website)
- **Swift 5.9+** (included with Xcode)
- **Git**

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/lakai.git
   cd lakai
   ```

2. **Open in Xcode**
   ```bash
   open Lakai.xcodeproj
   ```

3. **Verify build**
   ```bash
   ./Tools/build_test_app.sh
   ```
   
   A successful build produces `Build/Lakai.app`.

4. **Run the app**
   ```bash
   open Build/Lakai.app
   ```

---

## Code Style & Conventions

### Swift Guidelines

- Follow [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use descriptive naming: `projectSummaries` instead of `projects`
- Prefer clarity over brevity: explicit is better than implicit

### File Organization

**Views & Components**
- Keep view files under 300 lines
- Extract complex subviews into separate files
- Use `@ViewBuilder` for conditional content

**Services**
- Isolate business logic from UI
- Use `@MainActor` for state that affects the UI
- Write deterministic, testable methods

**Models**
- Keep data structures flat and explicit
- Use `Codable` for XML-compatible types
- Document required vs. optional fields

### Comments & Documentation

- Write useful comments explaining *why*, not *what*
- Use `/// ` for public function/type documentation
- Add brief inline comments for complex logic
- Update claude.md and claude_architecture.md when making structural changes

### Example

```swift
/// Parses script text and extracts shots based on marker lines.
/// - Parameter script: Raw script string
/// - Returns: Array of extracted Shot objects
func parseScriptIntoShots(_ script: String) -> [Shot] {
    // Implementation prioritizes robust marker detection over perfect parsing
    // because production scripts are often messy and ad-hoc
}
```

---

## Project Structure Guidelines

**Location** → **Responsibility**

| Directory | Files | Purpose |
|-----------|-------|---------|
| `/Models` | `ProjectModels.swift` | Core data types (Shot, ShotSize, ProjectDocument) |
| `/Services` | Business logic | AppState, Persistence, Sync, Scheduling, PDF Export |
| `/Views` | UI screens | RootView, OverviewView, WorkspaceView |
| `/Components` | Reusable UI | ShotCardView, ScriptTextEditor |
| `/Utilities` | Theme.swift | Shared constants, formatters, colors |
| `/Assets.xcassets` | Image & color sets | App icon, document icons |

---

## Branch Naming

Use descriptive branch names:

```
feature/script-sync-bidirectional
bugfix/schedule-timing-calculation
docs/update-architecture-guide
chore/upgrade-swiftui-components
```

---

## Commit Messages

Write clear, concise commit messages:

```
feat: add bidirectional script-to-shotlist sync

- Parse script markers (•, #, -, *, [...])
- Extract German and English shot sizes
- Auto-regenerate script when shotlist changes
- Preserves shot descriptions and notes

Closes #42
```

**Format:**
- **Type** (feat, fix, docs, refactor, chore, test)
- **Scope** (optional but recommended): area of change
- **Subject**: imperative mood, no period, max 50 chars
- **Body**: detailed explanation (wrapped at 72 chars), separated by blank line
- **References**: link to issues with "Closes #123"

---

## Pull Request Process

### Before You Start

1. **Check existing issues** – Make sure your feature/fix isn't already in progress
2. **Open a discussion issue** – For large features, discuss approach first
3. **Create a feature branch** – Use naming convention above

### During Development

1. **Keep commits atomic** – One logical change per commit
2. **Test locally** – Build and manually test the feature
3. **Update documentation** – Keep claude.md and claude_architecture.md in sync
4. **Build the app** – Run `./Tools/build_test_app.sh` to verify no regressions

### Submitting a PR

1. **Push your branch**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open a pull request** on GitHub with:
   - **Title**: Brief description (matching commit message style)
   - **Description**: 
     - What problem does this solve?
     - How does the implementation work?
     - Any testing done?
     - Screenshots or demos (if applicable)
   - **Related issues**: "Closes #123" or "Fixes #456"

3. **Example PR Template**
   ```markdown
   ## Description
   Add bidirectional sync between script edits and shotlist.

   ## Problem
   Previously, edits to the script didn't update the shotlist, 
   requiring manual re-entry.

   ## Solution
   - Parse script for shot markers (•, #, -, *, [...])
   - Extract shot sizes and descriptions automatically
   - Regenerate script when shotlist is edited
   - Preserve round-trip consistency

   ## Testing
   - Created project with sample script
   - Verified script → shotlist sync
   - Verified shotlist → script regeneration
   - Tested with German shot sizes

   ## Checklist
   - [x] Code follows style guidelines
   - [x] Local build passes: `./Tools/build_test_app.sh`
   - [x] Documentation updated (claude.md, claude_architecture.md)
   - [x] No new compiler warnings
   - [x] Manual testing complete
   ```

### Code Review

- Respond to feedback promptly
- Ask questions if suggestions are unclear
- Mark conversations as resolved once addressed
- Don't worry about polite disagreement – we value good discussion

---

## Making Structural Changes

**Non-negotiable:** If you modify data structures, services, or architecture, you **must** update:

1. **claude.md** – Product scope and functional requirements sections
2. **claude_architecture.md** – Technical architecture, data flows, XML format
3. **README.md** – Project structure, services, and features sections

This keeps documentation current and helps future contributors understand the system.

---

## Testing & QA

### Manual Testing Checklist

Before submitting a PR:

- [ ] App builds without warnings: `./Tools/build_test_app.sh`
- [ ] Feature works as intended
- [ ] Related features still work
- [ ] No visual regressions in existing views
- [ ] XML persistence works (create project, close, reopen)
- [ ] PDF export produces correct output
- [ ] Drag-and-drop still responsive

### Reporting Bugs

If you find a bug, please open an issue with:
- **Reproduction steps** – How to reliably trigger the bug
- **Expected behavior** – What should happen
- **Actual behavior** – What actually happens
- **Environment** – macOS version, Xcode version
- **Screenshots/logs** – If applicable

---

## Documentation

### Updating Documentation

When making changes, update relevant files:

| File | When to Update |
|------|---|
| **README.md** | Feature additions, structural changes, new services |
| **claude.md** | Scope changes, new requirements, design decisions |
| **claude_architecture.md** | Technical changes, new data flows, XML structure changes |
| **CONTRIBUTING.md** | Development workflow changes, new tools/prerequisites |

### Documentation Standards

- Keep language clear and concise
- Use code examples for complex concepts
- Link to relevant sections
- Update table of contents when adding sections

---

## Troubleshooting

### Common Issues

**Build fails with Swift module not found**
```bash
# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*
open Lakai.xcodeproj
```

**Xcode can't find resources**
```bash
# Clean build folder
Cmd + Shift + K
# Then rebuild
Cmd + B
```

**Git conflicts after pull**
```bash
git fetch origin
git rebase origin/main  # or git merge origin/main
# Resolve conflicts in Xcode, then commit
```

---

## Getting Help

- **Documentation**: See [README.md](README.md) and linked docs
- **Architecture deep-dive**: Read [claude_architecture.md](claude_architecture.md)
- **Open an issue**: For bugs or feature discussions
- **Ask in PR comments**: Feel free to ask clarifying questions during review

---

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions. We're building this project together, and diverse perspectives make it better.

---

## License

By contributing, you agree that your contributions will be licensed under the same MIT License as the project.

---

Thank you for contributing to Lakai! 🎬

