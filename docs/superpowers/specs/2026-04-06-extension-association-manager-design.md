# Extension Association Manager Design

## Goal

Build a native macOS GUI that lets users inspect and manage `file extension -> default app` associations from a single table-based interface, without going through Finder's `Get Info` flow.

## Scope

### In Scope for V1

- Show a centralized table of known file extensions.
- Show the current default app for each extension.
- Show all candidate apps that can open each extension.
- Support search, sorting, and multi-selection.
- Support batch-changing multiple selected extensions to the same app.
- Support manually adding an extension and assigning a default app.
- Surface clear status and failure states when system data is missing or inconsistent.

### Out of Scope for V1

- URL scheme management.
- Folder default-app management.
- Advanced UTI / UTType management UI.
- Automatic root-cause analysis of "association pollution".
- Undo history, snapshots, or restore points.
- Rule templates such as "all images -> Preview".
- Background live monitoring of association changes.

## Product Direction

The product should feel like a management console, not a guided wizard and not a thin wrapper over Finder's existing interaction. The main job is to make system state visible at a glance, then make bulk cleanup fast and predictable.

The default mental model for users is:

- Each row is one file extension.
- Each row shows what app owns it now.
- Each row shows what other apps also claim it.
- Users can select many rows and set one target app across all of them.

The UI should prioritize density, clarity, and speed over oversized controls or tutorial-like flows.

## Main UI

### Primary Layout

Use a table-manager layout with a main table and a right-side detail panel.

- Main table: one row per extension.
- Right panel in single-selection mode: detailed information for the selected extension.
- Right panel in multi-selection mode: batch action surface for the current selection.

### Table Columns

The default visible columns should be:

- `Extension`
- `Default App`
- `Candidate Apps`
- `Status`

Optional future columns can exist later, but V1 should stay focused.

### Toolbar

The toolbar should include:

- Search field
- Refresh button
- Batch action trigger: `Set Selected to App`
- Add extension trigger: `Add Extension`

### Detail Panel

When one row is selected, show:

- Normalized extension value
- Current default app
- Candidate apps list
- App metadata for the selected default app:
  - app name
  - icon
  - bundle identifier
  - app path
- Status explanation
- Last operation result for that extension, if available
- Action to change the app for this single extension

When multiple rows are selected, replace single-row details with:

- Selection count
- Target app picker
- Batch apply action
- Summary of the last batch result for the selected set, if relevant

## Domain Model

The central record is `ExtensionAssociationRow`.

### ExtensionAssociationRow

- `id`
- `rawExtension`
- `normalizedExtension`
- `displayExtension`
- `currentDefaultApp`
- `candidateApps`
- `statusFlags`
- `isUserAdded`
- `lastUpdatedAt`
- `lastOperationResult`

### App Descriptor

Represent apps in a user-facing way rather than exposing bundle identifiers as the primary label.

- `displayName`
- `bundleIdentifier`
- `appURL`
- `icon`
- `isAvailable`

### Status Flags

V1 should support these status flags:

- `noDefaultApp`
- `missingDefaultApp`
- `singleCandidate`
- `manyCandidates`
- `userAddedRule`
- `writePendingVerification`
- `writeFailed`

These flags drive badges, warnings, and filterable UI states.

## Data Semantics

### Default App

`currentDefaultApp` means the app that macOS currently resolves as the preferred app for opening files with that extension.

### Candidate Apps

`candidateApps` means apps that declare support for the extension or for the content type backing that extension. This is not limited to the current default app.

### Known Extensions

The table merges two sources:

- System-known extensions discovered from Launch Services / UTType-derived data
- User-added extension entries created inside the app

The merged list is what the user manages.

### Normalization

The app should accept both `.json` and `json` as input. Internally it stores a normalized lowercase value without the leading dot. Display formatting restores the leading dot.

If a manually added extension already exists in the table, the app should open the existing row rather than creating a duplicate.

## Core Flows

### Initial Load

On launch:

1. Load known extension rows.
2. Resolve default apps.
3. Resolve candidate apps.
4. Derive status flags.
5. Render the table.

If loading fails, show an explicit error state with retry. Do not render an empty table that looks like valid data.

### Search and Sorting

Search should match:

- extension text
- default app name
- candidate app names

Sorting should work on each primary column. Default sort is ascending by extension.

### Single-Item Change

For a selected row:

1. User triggers app reassignment.
2. App picker opens with name, icon, bundle identifier, and path.
3. User confirms target app.
4. The app writes the new association.
5. The row is refreshed.
6. The result is shown as success, failure, or pending verification.

### Batch Change

For multiple selected rows:

1. User selects several rows in the table.
2. User triggers `Set Selected to App`.
3. User chooses one target app.
4. The system writes changes per extension.
5. Each extension result is recorded independently.
6. A summary is shown, for example: `12 succeeded, 2 failed`.
7. Failed rows can show the concrete failure reason.

Batch execution is intentionally partial-success capable. V1 should not attempt all-or-nothing rollback.

### Add Extension

The add-extension interaction should be a compact modal or sheet:

- Input extension
- Select target app
- Confirm

Validation rules:

- extension cannot be empty
- extension is normalized before write
- target app is required

If the extension already exists, treat the action as editing that row's default app assignment.

## Error Handling

The app should prefer human-readable failures over raw system terminology.

Examples:

- `No default app is currently set for this extension.`
- `The current default app can no longer be found on disk.`
- `macOS did not accept this default-app change.`
- `The change was submitted, but the refreshed system state does not yet confirm it.`

### Error Cases to Handle

- initial load failure
- no default app
- default app path missing
- no candidate apps returned
- batch operation partial failure
- write accepted but refresh mismatch
- invalid manual extension input

## Architecture

Use a native macOS application with SwiftUI as the main UI layer. If table behavior or selection behavior exceeds what SwiftUI handles cleanly on the target macOS version, bridge to AppKit selectively instead of forcing the whole app into AppKit.

### Layers

#### 1. Association Repository

Responsible for:

- loading known extensions
- resolving current default apps
- resolving candidate apps
- refreshing rows after write operations

#### 2. Association Writer

Responsible for:

- writing `extension -> app` changes to the current user's system association state
- returning per-extension operation results

#### 3. View Model Layer

Responsible for:

- table state
- sorting
- filtering
- selection
- single-item actions
- batch action orchestration
- operation summaries

#### 4. UI Layer

Responsible for:

- table rendering
- detail panel rendering
- modals / sheets
- visual status badges
- error and empty states

All Launch Services and related system interaction should be isolated below the view-model boundary.

## System Integration Constraints

V1 should write associations only for the current user scope.

The implementation should assume:

- system reads and writes may not reflect instantly
- some extensions may map through content-type metadata rather than a simple direct declaration
- discovered extension lists may contain noisy or stale values from historical app registrations

The product should expose that reality clearly rather than pretending the system is cleaner than it is.

## Refresh Strategy

- Run a full scan on first load.
- After a write, refresh only the affected extensions first.
- Provide a manual `Refresh` action for users who install or remove apps outside the tool.
- Do not attempt background live monitoring in V1.

## Visual and Interaction Principles

- Dense, desktop-style table layout
- Minimal ceremony for frequent actions
- System state first, actions second
- Avoid exposing internal identifiers unless the user asks for detail
- Make bulk operations explicit and confirmable
- Always show what actually happened after a write

## Testing Strategy

### Unit Tests

Cover:

- extension normalization
- search matching
- sorting
- selection state transitions
- batch summary generation
- status flag derivation

### Service-Layer Tests

Use protocol-backed mocks for system integration and cover:

- extension with valid default app
- extension with no default app
- extension whose default app path is missing
- extension with many candidate apps
- partial batch write failure
- write-then-refresh mismatch

### Integration Tests

Cover the main flows:

- initial table load
- single-item reassignment
- batch reassignment
- add-extension flow

### Manual Validation

Validate on real macOS with a few known extensions such as:

- `.json`
- `.md`
- `.png`

For each:

- compare the app's displayed default app with Finder expectations
- change the default app in this tool
- verify the changed state is reflected afterward

## Acceptance Criteria

V1 is complete when:

- users can inspect known extensions and current default apps in one table
- users can inspect candidate apps for any listed extension
- users can search and sort the list efficiently
- users can multi-select rows and assign one app across them
- users can manually add an extension and assign an app
- the app reports success and failure clearly after write attempts
- the app distinguishes missing, empty, and suspicious states instead of hiding them

## Open Implementation Notes

These are implementation notes, not new scope:

- Keep the system-integration layer narrow and testable.
- Avoid mixing Launch Services calls directly into view code.
- Design row and app models so later expansion to URL schemes or UTType-level views remains possible without rewriting the table stack.
