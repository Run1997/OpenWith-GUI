# Default App Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add single-select table filtering by current default app through both a toolbar control and clickable default-app cells.

**Architecture:** Keep filtering entirely in the view-model and UI layers. The view model becomes the single source of truth for the selected default-app filter and derives both visible rows and toolbar options from loaded rows; the root view and table view only render controls and route user intent back into that shared state.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Observation, XCTest / Testing

---

## File Structure

- Modify: `Sources/OpenWithGUIApp/ViewModels/AssociationListViewModel.swift`
- Modify: `Sources/OpenWithGUIApp/Views/RootView.swift`
- Modify: `Sources/OpenWithGUIApp/Views/AssociationTableView.swift`
- Modify: `Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift`

## Task 1: Add failing tests for default-app filtering

**Files:**
- Modify: `Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift`

- [ ] **Step 1: Add failing tests for filter options, filtering, and selection reconciliation**

Update `Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift` with:

```swift
    @Test
    func exposesUniqueSortedDefaultAppFilterOptions() async throws {
        let preview = AppDescriptor(
            bundleIdentifier: "com.apple.Preview",
            displayName: "Preview",
            appURL: URL(fileURLWithPath: "/Applications/Preview.app"),
            isAvailable: true
        )
        let xcode = AppDescriptor(
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode",
            appURL: URL(fileURLWithPath: "/Applications/Xcode.app"),
            isAvailable: true
        )

        let repository = RepositoryStub(
            rows: [
                ExtensionAssociationRow(rawExtension: "png", currentDefaultApp: preview, candidateApps: [preview]),
                ExtensionAssociationRow(rawExtension: "jpg", currentDefaultApp: preview, candidateApps: [preview]),
                ExtensionAssociationRow(rawExtension: "swift", currentDefaultApp: xcode, candidateApps: [xcode])
            ],
            apps: [preview, xcode]
        )

        let viewModel = AssociationListViewModel(repository: repository, writer: WriterStub(results: []))
        await viewModel.load()

        #expect(viewModel.defaultAppFilterOptions.map(\.bundleIdentifier) == [
            "com.apple.Preview",
            "com.apple.dt.Xcode"
        ])
    }

    @Test
    func filtersVisibleRowsBySelectedDefaultApp() async throws {
        let preview = AppDescriptor(
            bundleIdentifier: "com.apple.Preview",
            displayName: "Preview",
            appURL: URL(fileURLWithPath: "/Applications/Preview.app"),
            isAvailable: true
        )
        let xcode = AppDescriptor(
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode",
            appURL: URL(fileURLWithPath: "/Applications/Xcode.app"),
            isAvailable: true
        )

        let repository = RepositoryStub(
            rows: [
                ExtensionAssociationRow(rawExtension: "png", currentDefaultApp: preview, candidateApps: [preview]),
                ExtensionAssociationRow(rawExtension: "jpg", currentDefaultApp: preview, candidateApps: [preview]),
                ExtensionAssociationRow(rawExtension: "swift", currentDefaultApp: xcode, candidateApps: [xcode])
            ],
            apps: [preview, xcode]
        )

        let viewModel = AssociationListViewModel(repository: repository, writer: WriterStub(results: []))
        await viewModel.load()
        viewModel.applyDefaultAppFilter(preview)

        #expect(viewModel.visibleRows.map(\.normalizedExtension) == ["jpg", "png"])
    }

    @Test
    func clearsFilterBackToAllApps() async throws {
        let preview = AppDescriptor(
            bundleIdentifier: "com.apple.Preview",
            displayName: "Preview",
            appURL: URL(fileURLWithPath: "/Applications/Preview.app"),
            isAvailable: true
        )

        let repository = RepositoryStub(
            rows: [
                ExtensionAssociationRow(rawExtension: "png", currentDefaultApp: preview, candidateApps: [preview]),
                ExtensionAssociationRow(rawExtension: "json", currentDefaultApp: nil, candidateApps: [])
            ],
            apps: [preview]
        )

        let viewModel = AssociationListViewModel(repository: repository, writer: WriterStub(results: []))
        await viewModel.load()
        viewModel.applyDefaultAppFilter(preview)
        viewModel.clearDefaultAppFilter()

        #expect(viewModel.visibleRows.map(\.normalizedExtension) == ["json", "png"])
    }

    @Test
    func movesSelectionToFirstVisibleRowWhenFilterHidesCurrentSelection() async throws {
        let preview = AppDescriptor(
            bundleIdentifier: "com.apple.Preview",
            displayName: "Preview",
            appURL: URL(fileURLWithPath: "/Applications/Preview.app"),
            isAvailable: true
        )
        let xcode = AppDescriptor(
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode",
            appURL: URL(fileURLWithPath: "/Applications/Xcode.app"),
            isAvailable: true
        )

        let repository = RepositoryStub(
            rows: [
                ExtensionAssociationRow(rawExtension: "png", currentDefaultApp: preview, candidateApps: [preview]),
                ExtensionAssociationRow(rawExtension: "jpg", currentDefaultApp: preview, candidateApps: [preview]),
                ExtensionAssociationRow(rawExtension: "swift", currentDefaultApp: xcode, candidateApps: [xcode])
            ],
            apps: [preview, xcode]
        )

        let viewModel = AssociationListViewModel(repository: repository, writer: WriterStub(results: []))
        await viewModel.load()
        viewModel.selection = ["swift"]
        viewModel.applyDefaultAppFilter(preview)

        #expect(viewModel.selection == ["jpg"])
    }
```

- [ ] **Step 2: Run the view-model tests to verify they fail for missing filter APIs**

Run:

```bash
swift test --filter AssociationListViewModelTests
```

Expected: FAIL because filter properties and methods do not exist yet.

- [ ] **Step 3: Commit the failing tests**

Run:

```bash
git add Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift
git commit -m "test: cover default app filter behavior"
```

Expected: one commit containing the new failing tests.

## Task 2: Implement the view-model filter state and selection reconciliation

**Files:**
- Modify: `Sources/OpenWithGUIApp/ViewModels/AssociationListViewModel.swift`

- [ ] **Step 1: Add filter state, options, and actions**

Update `Sources/OpenWithGUIApp/ViewModels/AssociationListViewModel.swift` by adding:

```swift
    var selectedDefaultAppBundleIdentifier: String?

    var defaultAppFilterOptions: [AppDescriptor] {
        Dictionary(
            rows.compactMap { row in
                row.currentDefaultApp.map { ($0.bundleIdentifier, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        .values
        .sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
```

Add these methods:

```swift
    func applyDefaultAppFilter(_ app: AppDescriptor) {
        selectedDefaultAppBundleIdentifier = app.bundleIdentifier
        reconcileSelectionWithVisibleRows()
    }

    func clearDefaultAppFilter() {
        selectedDefaultAppBundleIdentifier = nil
        reconcileSelectionWithVisibleRows()
    }

    private func reconcileSelectionWithVisibleRows() {
        let visibleIdentifiers = Set(visibleRows.map(\.normalizedExtension))

        if selection.isSubset(of: visibleIdentifiers), !selection.isEmpty {
            return
        }

        if let firstRow = visibleRows.first {
            selection = [firstRow.normalizedExtension]
        } else {
            selection = []
        }
    }
```

Update `visibleRows` filtering logic so it applies the default-app filter after search:

```swift
        let defaultAppFilteredRows = filteredRows.filter { row in
            guard let selectedDefaultAppBundleIdentifier else {
                return true
            }

            return row.currentDefaultApp?.bundleIdentifier == selectedDefaultAppBundleIdentifier
        }
```

Then sort `defaultAppFilteredRows` instead of `filteredRows`.

- [ ] **Step 2: Re-run the view-model tests**

Run:

```bash
swift test --filter AssociationListViewModelTests
```

Expected: PASS with the new filter behavior covered.

- [ ] **Step 3: Commit the view-model filtering behavior**

Run:

```bash
git add Sources/OpenWithGUIApp/ViewModels/AssociationListViewModel.swift Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift
git commit -m "feat: add default app filter state"
```

Expected: one commit containing the filtering source of truth.

## Task 3: Add toolbar filter UI and clickable default-app cells

**Files:**
- Modify: `Sources/OpenWithGUIApp/Views/RootView.swift`
- Modify: `Sources/OpenWithGUIApp/Views/AssociationTableView.swift`

- [ ] **Step 1: Add the toolbar filter to the root view**

Update `Sources/OpenWithGUIApp/Views/RootView.swift` inside the toolbar group:

```swift
                Picker(
                    "Default App",
                    selection: Binding(
                        get: { viewModel.selectedDefaultAppBundleIdentifier ?? "__all__" },
                        set: { newValue in
                            if newValue == "__all__" {
                                viewModel.clearDefaultAppFilter()
                            } else if let app = viewModel.defaultAppFilterOptions.first(where: { $0.bundleIdentifier == newValue }) {
                                viewModel.applyDefaultAppFilter(app)
                            }
                        }
                    )
                ) {
                    Text("All Apps").tag("__all__")
                    ForEach(viewModel.defaultAppFilterOptions) { app in
                        Text(app.displayName).tag(app.bundleIdentifier)
                    }
                }
                .frame(width: 220)
```

- [ ] **Step 2: Show a filter-aware empty state**

Update the `.loaded` branch in `Sources/OpenWithGUIApp/Views/RootView.swift`:

```swift
            case .loaded:
                if viewModel.visibleRows.isEmpty {
                    ContentUnavailableView(
                        "No Matching Extensions",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(
                            viewModel.selectedDefaultAppBundleIdentifier == nil
                                ? "No extensions are currently available."
                                : "No extensions are currently opened by the selected app. Use Default App → All Apps to clear the filter."
                        )
                    )
                } else {
                    content
                }
```

- [ ] **Step 3: Make the default-app cell clickable**

Update `Sources/OpenWithGUIApp/Views/AssociationTableView.swift` by wrapping the default-app cell content:

```swift
                if let app = row.currentDefaultApp {
                    Button {
                        viewModel.applyDefaultAppFilter(app)
                    } label: {
                        HStack(spacing: 4) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path))
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(app.displayName)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
```

- [ ] **Step 4: Run full verification**

Run:

```bash
swift test
swift build
```

Expected: all tests pass and the app builds with the new filter UI.

- [ ] **Step 5: Commit the UI integration**

Run:

```bash
git add Sources/OpenWithGUIApp/Views Sources/OpenWithGUIApp/ViewModels/AssociationListViewModel.swift Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift
git commit -m "feat: add default app table filtering"
```

Expected: one commit containing the toolbar filter and clickable cell behavior.

## Task 4: Launch and manually validate the filter flow

**Files:**
- No code changes required unless a defect is found

- [ ] **Step 1: Launch the app**

Run:

```bash
swift run OpenWithGUI
```

Expected: the app launches and stays open.

- [ ] **Step 2: Validate the approved scenarios**

Validate manually:

```text
1. Pick one app from Default App in the toolbar and confirm only matching rows remain.
2. Click a default app directly in the table and confirm the same filter is applied.
3. Switch the toolbar back to All Apps and confirm the full list returns.
4. Confirm the sidebar still points at a visible row after filtering changes.
5. Confirm the filtered view makes it easy to see that one app owns multiple extensions.
```

Expected: all five checks match the approved design.

- [ ] **Step 3: Commit only if manual validation required an extra fix**

Run only if an additional patch was needed:

```bash
git add Sources Tests
git commit -m "fix: polish default app filter behavior"
```

Expected: extra commit only if manual validation uncovered another defect.
