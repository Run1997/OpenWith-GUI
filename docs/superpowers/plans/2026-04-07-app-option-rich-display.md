# App Option Rich Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace plain-text app pickers in the toolbar filter flow and Add Extension flow with rich app choosers that show icon, app name, and bundle identifier.

**Architecture:** Reuse the existing app-picker presentation rather than introducing another separate list renderer. Add a small reusable chooser-option model that can represent both real apps and the toolbar's `All Apps` action, then route both RootView and AddExtensionSheet through the same richer selection surface.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Observation, XCTest / Testing

---

## File Structure

- Create: `Sources/OpenWithGUIApp/Models/AppPickerChoice.swift`
- Modify: `Sources/OpenWithGUIApp/Views/AppPickerSheet.swift`
- Modify: `Sources/OpenWithGUIApp/Views/AddExtensionSheet.swift`
- Modify: `Sources/OpenWithGUIApp/Views/RootView.swift`
- Create: `Tests/OpenWithGUIAppTests/Models/AppPickerChoiceTests.swift`

## Task 1: Add failing tests for chooser choice modeling

**Files:**
- Create: `Tests/OpenWithGUIAppTests/Models/AppPickerChoiceTests.swift`

- [ ] **Step 1: Add failing tests for app and special-choice rows**

Create `Tests/OpenWithGUIAppTests/Models/AppPickerChoiceTests.swift`:

```swift
import Foundation
import Testing
@testable import OpenWithGUIApp

struct AppPickerChoiceTests {
    @Test
    func appChoiceUsesAppIdentityForDisplay() {
        let app = AppDescriptor(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            appURL: URL(fileURLWithPath: "/Applications/TextEdit.app"),
            isAvailable: true
        )

        let choice = AppPickerChoice.app(app)

        #expect(choice.id == "app:com.apple.TextEdit")
        #expect(choice.title == "TextEdit")
        #expect(choice.subtitle == "com.apple.TextEdit")
    }

    @Test
    func specialChoiceCanRepresentAllAppsWithoutAnAppDescriptor() {
        let choice = AppPickerChoice.special(
            id: "all-apps",
            title: "All Apps",
            subtitle: "Show every current default app binding"
        )

        #expect(choice.id == "special:all-apps")
        #expect(choice.title == "All Apps")
        #expect(choice.subtitle == "Show every current default app binding")
        #expect(choice.appDescriptor == nil)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail for the missing model**

Run:

```bash
swift test --filter AppPickerChoiceTests
```

Expected: FAIL because `AppPickerChoice` does not exist yet.

- [ ] **Step 3: Commit the failing tests**

Run:

```bash
git add Tests/OpenWithGUIAppTests/Models/AppPickerChoiceTests.swift
git commit -m "test: cover rich app picker choices"
```

Expected: one commit containing the red tests.

## Task 2: Implement the chooser model and update the shared sheet

**Files:**
- Create: `Sources/OpenWithGUIApp/Models/AppPickerChoice.swift`
- Modify: `Sources/OpenWithGUIApp/Views/AppPickerSheet.swift`

- [ ] **Step 1: Implement the reusable chooser model**

Create `Sources/OpenWithGUIApp/Models/AppPickerChoice.swift`:

```swift
import Foundation

struct AppPickerChoice: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let appDescriptor: AppDescriptor?

    static func app(_ app: AppDescriptor) -> AppPickerChoice {
        AppPickerChoice(
            id: "app:\(app.bundleIdentifier)",
            title: app.displayName,
            subtitle: app.bundleIdentifier,
            appDescriptor: app
        )
    }

    static func special(id: String, title: String, subtitle: String) -> AppPickerChoice {
        AppPickerChoice(
            id: "special:\(id)",
            title: title,
            subtitle: subtitle,
            appDescriptor: nil
        )
    }
}
```

- [ ] **Step 2: Extend the shared picker sheet to support special leading items**

Update `Sources/OpenWithGUIApp/Views/AppPickerSheet.swift`:

```swift
struct AppPickerSheet: View {
    let apps: [AppDescriptor]
    let title: String
    let candidateApps: [AppDescriptor]
    let showsCandidateGrouping: Bool
    let leadingChoices: [AppPickerChoice]
    let onSelectChoice: (AppPickerChoice) -> Void
```

Replace selection handling inside the list rows:

```swift
                                onSelectChoice(.app(app))
                                dismiss()
```

Add a leading section above app sections:

```swift
                if !filteredLeadingChoices.isEmpty {
                    Section {
                        ForEach(filteredLeadingChoices) { choice in
                            Button {
                                onSelectChoice(choice)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .frame(width: 28, height: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(choice.title)
                                        Text(choice.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
```

Add:

```swift
    private var filteredLeadingChoices: [AppPickerChoice] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return leadingChoices.filter { choice in
            guard !query.isEmpty else { return true }
            return choice.title.lowercased().contains(query)
                || choice.subtitle.lowercased().contains(query)
        }
    }
```

- [ ] **Step 3: Run the choice tests**

Run:

```bash
swift test --filter AppPickerChoiceTests
```

Expected: PASS.

- [ ] **Step 4: Commit the shared chooser work**

Run:

```bash
git add Sources/OpenWithGUIApp/Models/AppPickerChoice.swift Sources/OpenWithGUIApp/Views/AppPickerSheet.swift Tests/OpenWithGUIAppTests/Models/AppPickerChoiceTests.swift
git commit -m "feat: add rich app picker choices"
```

Expected: one commit containing the model and shared sheet upgrade.

## Task 3: Switch toolbar filtering and Add Extension to the rich chooser

**Files:**
- Modify: `Sources/OpenWithGUIApp/Views/RootView.swift`
- Modify: `Sources/OpenWithGUIApp/Views/AddExtensionSheet.swift`

- [ ] **Step 1: Replace toolbar picker with a sheet-driven chooser**

Update `Sources/OpenWithGUIApp/Views/RootView.swift` to add:

```swift
    @State private var showingDefaultAppFilterPicker = false
```

Replace the toolbar `Picker` with:

```swift
                Button {
                    showingDefaultAppFilterPicker = true
                } label: {
                    Text(viewModel.selectedDefaultAppBundleIdentifier.flatMap { bundleIdentifier in
                        viewModel.defaultAppFilterOptions.first(where: { $0.bundleIdentifier == bundleIdentifier })?.displayName
                    } ?? "All Apps")
                }
```

Add a new sheet:

```swift
        .sheet(isPresented: $showingDefaultAppFilterPicker) {
            AppPickerSheet(
                apps: viewModel.defaultAppFilterOptions,
                title: "Filter by Default App",
                candidateApps: [],
                showsCandidateGrouping: false,
                leadingChoices: [
                    AppPickerChoice.special(
                        id: "all-apps",
                        title: "All Apps",
                        subtitle: "Show every current default app binding"
                    )
                ],
                onSelectChoice: { choice in
                    if choice.id == "special:all-apps" {
                        viewModel.clearDefaultAppFilter()
                    } else if let app = choice.appDescriptor {
                        viewModel.applyDefaultAppFilter(app)
                    }
                    showingDefaultAppFilterPicker = false
                }
            )
        }
```

- [ ] **Step 2: Replace Add Extension picker with a sheet-driven chooser**

Update `Sources/OpenWithGUIApp/Views/AddExtensionSheet.swift`:

```swift
import AppKit
import SwiftUI
```

Add state:

```swift
    @State private var showingAppPicker = false
```

Replace the `Picker` with:

```swift
            Button {
                showingAppPicker = true
            } label: {
                HStack(spacing: 12) {
                    if let selectedApp = apps.first(where: { $0.id == selectedAppID }) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: selectedApp.appURL.path))
                            .resizable()
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedApp.displayName)
                            Text(selectedApp.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Choose an app")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
```

Add sheet:

```swift
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(
                apps: apps,
                title: "Choose Default App",
                candidateApps: [],
                showsCandidateGrouping: false,
                leadingChoices: [],
                onSelectChoice: { choice in
                    selectedAppID = choice.appDescriptor?.id
                    showingAppPicker = false
                }
            )
        }
```

- [ ] **Step 3: Update existing `AppPickerSheet` call sites to pass the new callback shape**

Update both existing call sites in `Sources/OpenWithGUIApp/Views/RootView.swift`:

```swift
                leadingChoices: [],
                onSelectChoice: { choice in
                    guard let app = choice.appDescriptor else { return }
```

Then reuse the existing write logic with `app`.

- [ ] **Step 4: Run the full verification set**

Run:

```bash
swift test
swift build
```

Expected: all tests pass and the richer chooser UI builds cleanly.

- [ ] **Step 5: Commit the rich chooser integration**

Run:

```bash
git add Sources/OpenWithGUIApp/Views Sources/OpenWithGUIApp/Models/AppPickerChoice.swift Tests/OpenWithGUIAppTests/Models/AppPickerChoiceTests.swift
git commit -m "feat: show rich app choices in selection flows"
```

Expected: one commit containing the toolbar and add-extension chooser upgrade.

## Task 4: Launch and manually validate the upgraded choosers

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
1. Open the toolbar Default App chooser and confirm rows show icon, app name, and bundle id.
2. Choose one app and confirm default-app filtering still works.
3. Reopen the toolbar chooser and cancel it; confirm the current filter remains unchanged.
4. Open Add Extension and launch its app chooser; confirm rows show icon, app name, and bundle id.
5. Choose an app, return to the form, and confirm the selected app persists until Add or Cancel.
```

Expected: all five checks match the approved design.

- [ ] **Step 3: Commit only if manual validation required an extra fix**

Run only if an additional patch was needed:

```bash
git add Sources Tests
git commit -m "fix: polish rich app chooser behavior"
```

Expected: extra commit only if manual validation revealed another defect.
