# Extension Association Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS GUI that shows `file extension -> default app` associations in a table and lets the user batch-change selected extensions to the same app.

**Architecture:** Use a Swift Package macOS app with SwiftUI for the main window and a narrow Launch Services integration layer for reading and writing associations. Build a scan-based application catalog from installed `.app` bundles, merge it with Launch Services default resolution and locally persisted user-added extensions, and drive the UI from a testable view model.

**Tech Stack:** Swift 6, SwiftUI, AppKit, CoreServices / LaunchServices, UniformTypeIdentifiers, XCTest

---

## File Structure

### App Files

- Create: `Package.swift`
- Create: `Sources/OpenWithGUIApp/OpenWithGUIApp.swift`
- Create: `Sources/OpenWithGUIApp/Models/AppDescriptor.swift`
- Create: `Sources/OpenWithGUIApp/Models/AssociationOperationResult.swift`
- Create: `Sources/OpenWithGUIApp/Models/AssociationStatusFlag.swift`
- Create: `Sources/OpenWithGUIApp/Models/ExtensionAssociationRow.swift`
- Create: `Sources/OpenWithGUIApp/Services/AssociationRepository.swift`
- Create: `Sources/OpenWithGUIApp/Services/AssociationWriter.swift`
- Create: `Sources/OpenWithGUIApp/Services/AppCatalogScanner.swift`
- Create: `Sources/OpenWithGUIApp/Services/DocumentTypeParser.swift`
- Create: `Sources/OpenWithGUIApp/Services/LaunchServicesClient.swift`
- Create: `Sources/OpenWithGUIApp/Services/SystemAssociationRepository.swift`
- Create: `Sources/OpenWithGUIApp/Services/SystemAssociationWriter.swift`
- Create: `Sources/OpenWithGUIApp/Services/UserAddedExtensionStore.swift`
- Create: `Sources/OpenWithGUIApp/ViewModels/AssociationListViewModel.swift`
- Create: `Sources/OpenWithGUIApp/Views/RootView.swift`
- Create: `Sources/OpenWithGUIApp/Views/AssociationTableView.swift`
- Create: `Sources/OpenWithGUIApp/Views/AssociationDetailSidebar.swift`
- Create: `Sources/OpenWithGUIApp/Views/BatchActionSidebar.swift`
- Create: `Sources/OpenWithGUIApp/Views/AppPickerSheet.swift`
- Create: `Sources/OpenWithGUIApp/Views/AddExtensionSheet.swift`

### Test Files

- Create: `Tests/OpenWithGUIAppTests/Models/ExtensionAssociationRowTests.swift`
- Create: `Tests/OpenWithGUIAppTests/Services/DocumentTypeParserTests.swift`
- Create: `Tests/OpenWithGUIAppTests/Services/UserAddedExtensionStoreTests.swift`
- Create: `Tests/OpenWithGUIAppTests/Services/SystemAssociationRepositoryTests.swift`
- Create: `Tests/OpenWithGUIAppTests/Services/SystemAssociationWriterTests.swift`
- Create: `Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift`

## Task 1: Bootstrap the package and foundational models

**Files:**
- Create: `Package.swift`
- Create: `Sources/OpenWithGUIApp/OpenWithGUIApp.swift`
- Create: `Sources/OpenWithGUIApp/Views/RootView.swift`
- Create: `Sources/OpenWithGUIApp/Models/AppDescriptor.swift`
- Create: `Sources/OpenWithGUIApp/Models/AssociationOperationResult.swift`
- Create: `Sources/OpenWithGUIApp/Models/AssociationStatusFlag.swift`
- Create: `Sources/OpenWithGUIApp/Models/ExtensionAssociationRow.swift`
- Test: `Tests/OpenWithGUIAppTests/Models/ExtensionAssociationRowTests.swift`

- [ ] **Step 1: Initialize git and write the failing model tests**

Run:

```bash
git init
mkdir -p Sources/OpenWithGUIApp/{Models,Views,Services,ViewModels} Tests/OpenWithGUIAppTests/{Models,Services,ViewModels}
```

Expected: `Initialized empty Git repository` and the directory tree exists.

Write `Tests/OpenWithGUIAppTests/Models/ExtensionAssociationRowTests.swift`:

```swift
import Foundation
import Testing
@testable import OpenWithGUIApp

struct ExtensionAssociationRowTests {
    @Test
    func normalizeStripsDotsWhitespaceAndLowercases() {
        #expect(ExtensionAssociationRow.normalize(" .JSON ") == "json")
        #expect(ExtensionAssociationRow.normalize("md") == "md")
        #expect(ExtensionAssociationRow.normalize("...") == nil)
    }

    @Test
    func derivesStatusFlagsFromAvailabilityCandidatesAndWriteResult() {
        let missingApp = AppDescriptor(
            bundleIdentifier: "com.example.missing",
            displayName: "Missing App",
            appURL: URL(fileURLWithPath: "/Missing.app"),
            isAvailable: false
        )

        let row = ExtensionAssociationRow(
            rawExtension: ".json",
            currentDefaultApp: missingApp,
            candidateApps: [missingApp],
            isUserAdded: true,
            lastOperationResult: .failed(message: "write failed")
        )

        #expect(row.displayExtension == ".json")
        #expect(Set(row.statusFlags) == [
            .missingDefaultApp,
            .singleCandidate,
            .userAddedRule,
            .writeFailed
        ])
    }
}
```

- [ ] **Step 2: Create the package manifest and minimal app shell**

Write `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenWithGUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenWithGUI", targets: ["OpenWithGUIApp"])
    ],
    targets: [
        .executableTarget(
            name: "OpenWithGUIApp",
            path: "Sources/OpenWithGUIApp"
        ),
        .testTarget(
            name: "OpenWithGUIAppTests",
            dependencies: ["OpenWithGUIApp"],
            path: "Tests/OpenWithGUIAppTests"
        )
    ]
)
```

Write `Sources/OpenWithGUIApp/OpenWithGUIApp.swift`:

```swift
import SwiftUI

@main
struct OpenWithGUIApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .defaultSize(width: 1200, height: 760)
    }
}
```

Write `Sources/OpenWithGUIApp/Views/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        Text("Extension Association Manager")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: Implement the model layer**

Write `Sources/OpenWithGUIApp/Models/AppDescriptor.swift`:

```swift
import Foundation

struct AppDescriptor: Identifiable, Hashable, Sendable {
    let bundleIdentifier: String
    let displayName: String
    let appURL: URL
    let isAvailable: Bool

    var id: String { bundleIdentifier }
}
```

Write `Sources/OpenWithGUIApp/Models/AssociationStatusFlag.swift`:

```swift
import Foundation

enum AssociationStatusFlag: String, CaseIterable, Sendable {
    case noDefaultApp
    case missingDefaultApp
    case singleCandidate
    case manyCandidates
    case userAddedRule
    case writePendingVerification
    case writeFailed
}
```

Write `Sources/OpenWithGUIApp/Models/AssociationOperationResult.swift`:

```swift
import Foundation

enum AssociationOperationResult: Equatable, Sendable {
    case idle
    case succeeded(message: String)
    case failed(message: String)
    case pendingVerification(message: String)
}
```

Write `Sources/OpenWithGUIApp/Models/ExtensionAssociationRow.swift`:

```swift
import Foundation

struct ExtensionAssociationRow: Identifiable, Equatable, Sendable {
    static let manyCandidateThreshold = 5

    let normalizedExtension: String
    let rawExtension: String
    let currentDefaultApp: AppDescriptor?
    let candidateApps: [AppDescriptor]
    let isUserAdded: Bool
    let lastOperationResult: AssociationOperationResult

    var id: String { normalizedExtension }
    var displayExtension: String { ".\(normalizedExtension)" }
    var statusFlags: [AssociationStatusFlag] { Self.makeStatusFlags(for: self) }

    init(
        rawExtension: String,
        currentDefaultApp: AppDescriptor?,
        candidateApps: [AppDescriptor],
        isUserAdded: Bool = false,
        lastOperationResult: AssociationOperationResult = .idle
    ) {
        guard let normalized = Self.normalize(rawExtension) else {
            preconditionFailure("ExtensionAssociationRow requires a non-empty normalized extension")
        }

        self.normalizedExtension = normalized
        self.rawExtension = rawExtension
        self.currentDefaultApp = currentDefaultApp
        self.candidateApps = candidateApps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        self.isUserAdded = isUserAdded
        self.lastOperationResult = lastOperationResult
    }

    func withOperationResult(_ result: AssociationOperationResult) -> ExtensionAssociationRow {
        ExtensionAssociationRow(
            rawExtension: rawExtension,
            currentDefaultApp: currentDefaultApp,
            candidateApps: candidateApps,
            isUserAdded: isUserAdded,
            lastOperationResult: result
        )
    }

    static func normalize(_ input: String) -> String? {
        let trimmed = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()

        return trimmed.isEmpty ? nil : trimmed
    }

    private static func makeStatusFlags(for row: ExtensionAssociationRow) -> [AssociationStatusFlag] {
        var flags: [AssociationStatusFlag] = []

        if row.currentDefaultApp == nil {
            flags.append(.noDefaultApp)
        } else if row.currentDefaultApp?.isAvailable == false {
            flags.append(.missingDefaultApp)
        }

        if row.candidateApps.count == 1 {
            flags.append(.singleCandidate)
        }

        if row.candidateApps.count >= manyCandidateThreshold {
            flags.append(.manyCandidates)
        }

        if row.isUserAdded {
            flags.append(.userAddedRule)
        }

        switch row.lastOperationResult {
        case .pendingVerification:
            flags.append(.writePendingVerification)
        case .failed:
            flags.append(.writeFailed)
        case .idle, .succeeded:
            break
        }

        return flags
    }
}
```

- [ ] **Step 4: Run tests and build to verify the foundation**

Run:

```bash
swift test --filter ExtensionAssociationRowTests
swift build
```

Expected:

- `swift test` reports both `ExtensionAssociationRowTests` passing.
- `swift build` completes without compile errors.

- [ ] **Step 5: Commit the foundation**

Run:

```bash
git add Package.swift Sources Tests
git commit -m "feat: scaffold package and association models"
```

Expected: one commit containing the package manifest, app shell, and model layer.

## Task 2: Build installed-app scanning and user-added extension persistence

**Files:**
- Create: `Sources/OpenWithGUIApp/Services/DocumentTypeParser.swift`
- Create: `Sources/OpenWithGUIApp/Services/AppCatalogScanner.swift`
- Create: `Sources/OpenWithGUIApp/Services/UserAddedExtensionStore.swift`
- Test: `Tests/OpenWithGUIAppTests/Services/DocumentTypeParserTests.swift`
- Test: `Tests/OpenWithGUIAppTests/Services/UserAddedExtensionStoreTests.swift`

- [ ] **Step 1: Write failing tests for document parsing and user-added storage**

Write `Tests/OpenWithGUIAppTests/Services/DocumentTypeParserTests.swift`:

```swift
import Foundation
import Testing
@testable import OpenWithGUIApp

struct DocumentTypeParserTests {
    @Test
    func collectsDirectExtensionsAndUTTypeDerivedExtensions() {
        let infoPlist: [String: Any] = [
            "CFBundleDocumentTypes": [
                [
                    "CFBundleTypeExtensions": ["json", "JSON", "*"],
                    "LSItemContentTypes": ["public.yaml"]
                ]
            ]
        ]

        let parser = DocumentTypeParser(
            preferredExtensionForTypeIdentifier: { identifier in
                identifier == "public.yaml" ? "yaml" : nil
            }
        )

        let parsed = parser.extensions(from: infoPlist)

        #expect(parsed == Set(["json", "yaml"]))
    }
}
```

Write `Tests/OpenWithGUIAppTests/Services/UserAddedExtensionStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import OpenWithGUIApp

struct UserAddedExtensionStoreTests {
    @Test
    func savesNormalizedExtensionsWithoutDuplicates() throws {
        let suiteName = "UserAddedExtensionStoreTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = UserAddedExtensionStore(
            defaults: defaults,
            defaultsKey: "userAddedExtensions"
        )

        try store.add(".JSON")
        try store.add("json")
        try store.add(" md ")

        #expect(try store.load() == Set(["json", "md"]))
    }
}
```

- [ ] **Step 2: Implement the parser and persistent store**

Write `Sources/OpenWithGUIApp/Services/DocumentTypeParser.swift`:

```swift
import Foundation
import UniformTypeIdentifiers

struct DocumentTypeParser {
    var preferredExtensionForTypeIdentifier: (String) -> String?

    init(preferredExtensionForTypeIdentifier: @escaping (String) -> String? = { identifier in
        UTType(identifier)?.preferredFilenameExtension
    }) {
        self.preferredExtensionForTypeIdentifier = preferredExtensionForTypeIdentifier
    }

    func extensions(from infoPlist: [String: Any]) -> Set<String> {
        guard let documentTypes = infoPlist["CFBundleDocumentTypes"] as? [[String: Any]] else {
            return []
        }

        var result: Set<String> = []

        for documentType in documentTypes {
            let directExtensions = (documentType["CFBundleTypeExtensions"] as? [String] ?? [])
                .compactMap(ExtensionAssociationRow.normalize)
                .filter { $0 != "*" }

            result.formUnion(directExtensions)

            let contentTypes = documentType["LSItemContentTypes"] as? [String] ?? []
            for identifier in contentTypes {
                if let derived = preferredExtensionForTypeIdentifier(identifier),
                   let normalized = ExtensionAssociationRow.normalize(derived) {
                    result.insert(normalized)
                }
            }
        }

        return result
    }
}
```

Write `Sources/OpenWithGUIApp/Services/UserAddedExtensionStore.swift`:

```swift
import Foundation

struct UserAddedExtensionStore {
    let defaults: UserDefaults
    let defaultsKey: String

    init(
        defaults: UserDefaults = .standard,
        defaultsKey: String = "userAddedExtensions"
    ) {
        self.defaults = defaults
        self.defaultsKey = defaultsKey
    }

    func load() throws -> Set<String> {
        let stored = defaults.stringArray(forKey: defaultsKey) ?? []
        return Set(stored.compactMap(ExtensionAssociationRow.normalize))
    }

    func add(_ rawExtension: String) throws {
        guard let normalized = ExtensionAssociationRow.normalize(rawExtension) else {
            throw ValidationError.invalidExtension
        }

        var current = try load()
        current.insert(normalized)
        defaults.set(Array(current).sorted(), forKey: defaultsKey)
    }

    enum ValidationError: Error {
        case invalidExtension
    }
}
```

- [ ] **Step 3: Implement the app catalog scanner**

Write `Sources/OpenWithGUIApp/Services/AppCatalogScanner.swift`:

```swift
import AppKit
import Foundation

struct InstalledAppCatalog: Sendable {
    let allApps: [AppDescriptor]
    let candidateAppsByExtension: [String: [AppDescriptor]]
}

struct AppCatalogScanner {
    let parser: DocumentTypeParser
    let fileManager: FileManager
    let applicationDirectories: [URL]

    init(
        parser: DocumentTypeParser = DocumentTypeParser(),
        fileManager: FileManager = .default,
        applicationDirectories: [URL]? = nil
    ) {
        self.parser = parser
        self.fileManager = fileManager
        self.applicationDirectories = applicationDirectories ?? [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
    }

    func scan() -> InstalledAppCatalog {
        var allApps: [AppDescriptor] = []
        var candidates: [String: [AppDescriptor]] = [:]

        for appURL in discoverApplicationBundles() {
            guard let bundle = Bundle(url: appURL),
                  let bundleIdentifier = bundle.bundleIdentifier,
                  let info = bundle.infoDictionary else {
                continue
            }

            let app = AppDescriptor(
                bundleIdentifier: bundleIdentifier,
                displayName: fileManager.displayName(atPath: appURL.path),
                appURL: appURL,
                isAvailable: fileManager.fileExists(atPath: appURL.path)
            )

            allApps.append(app)

            for normalizedExtension in parser.extensions(from: info) {
                candidates[normalizedExtension, default: []].append(app)
            }
        }

        let deduplicated = candidates.mapValues { apps in
            Dictionary(grouping: apps, by: \.bundleIdentifier)
                .compactMap { $0.value.first }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }

        return InstalledAppCatalog(
            allApps: allApps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            candidateAppsByExtension: deduplicated
        )
    }

    private func discoverApplicationBundles() -> [URL] {
        applicationDirectories.flatMap { directory in
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            return enumerator.compactMap { item in
                guard let url = item as? URL, url.pathExtension == "app" else {
                    return nil
                }
                return url
            }
        }
    }
}
```

- [ ] **Step 4: Run the service tests**

Run:

```bash
swift test --filter DocumentTypeParserTests
swift test --filter UserAddedExtensionStoreTests
```

Expected: both test groups pass and no compilation errors occur in the new services.

- [ ] **Step 5: Commit scanning and persistence**

Run:

```bash
git add Sources/OpenWithGUIApp/Services Tests/OpenWithGUIAppTests/Services
git commit -m "feat: scan installed apps and persist user extensions"
```

Expected: one commit containing the parser, scanner, and user-added store.

## Task 3: Implement Launch Services-backed association reads and writes

**Files:**
- Create: `Sources/OpenWithGUIApp/Services/AssociationRepository.swift`
- Create: `Sources/OpenWithGUIApp/Services/AssociationWriter.swift`
- Create: `Sources/OpenWithGUIApp/Services/LaunchServicesClient.swift`
- Create: `Sources/OpenWithGUIApp/Services/SystemAssociationRepository.swift`
- Create: `Sources/OpenWithGUIApp/Services/SystemAssociationWriter.swift`
- Test: `Tests/OpenWithGUIAppTests/Services/SystemAssociationRepositoryTests.swift`
- Test: `Tests/OpenWithGUIAppTests/Services/SystemAssociationWriterTests.swift`

- [ ] **Step 1: Write failing tests for repository load and writer behavior**

Write `Tests/OpenWithGUIAppTests/Services/SystemAssociationRepositoryTests.swift`:

```swift
import Foundation
import Testing
@testable import OpenWithGUIApp

struct SystemAssociationRepositoryTests {
    @Test
    func mergesScannedAndUserAddedExtensionsAndResolvesDefaults() async throws {
        let textEdit = AppDescriptor(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            appURL: URL(fileURLWithPath: "/Applications/TextEdit.app"),
            isAvailable: true
        )

        let repository = SystemAssociationRepository(
            scanner: .init(
                scanHandler: {
                    InstalledAppCatalog(
                        allApps: [textEdit],
                        candidateAppsByExtension: ["json": [textEdit]]
                    )
                }
            ),
            launchServices: .init(
                defaultAppURLHandler: { identifier in
                    identifier == "public.json" ? textEdit.appURL : nil
                },
                setDefaultHandler: { _, _ in },
                allHandlersHandler: { _ in [] }
            ),
            userStore: .init(
                loadHandler: { Set(["md"]) },
                addHandler: { _ in }
            )
        )

        let rows = try await repository.loadRows()

        #expect(rows.map(\.normalizedExtension) == ["json", "md"])
        #expect(rows.first?.currentDefaultApp?.bundleIdentifier == "com.apple.TextEdit")
        #expect(rows.last?.statusFlags.contains(.userAddedRule) == true)
    }
}
```

Write `Tests/OpenWithGUIAppTests/Services/SystemAssociationWriterTests.swift`:

```swift
import Foundation
import Testing
@testable import OpenWithGUIApp

struct SystemAssociationWriterTests {
    @Test
    func failsUnknownExtensionsAndWritesRecognizedOnes() async throws {
        let writer = SystemAssociationWriter(
            launchServices: .init(
                defaultAppURLHandler: { _ in nil },
                setDefaultHandler: { _, _ in },
                allHandlersHandler: { _ in [] }
            ),
            typeIdentifierResolver: { normalizedExtension in
                normalizedExtension == "json" ? "public.json" : nil
            }
        )

        let app = AppDescriptor(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            appURL: URL(fileURLWithPath: "/Applications/TextEdit.app"),
            isAvailable: true
        )

        let results = try await writer.setDefaultApp(app, for: ["json", "foo"])

        #expect(results.count == 2)
        #expect(results.first?.normalizedExtension == "json")
        #expect(results.first?.errorMessage == nil)
        #expect(results.last?.normalizedExtension == "foo")
        #expect(results.last?.errorMessage == "macOS does not recognize this extension yet.")
    }
}
```

- [ ] **Step 2: Define the service contracts and Launch Services wrapper**

Write `Sources/OpenWithGUIApp/Services/AssociationRepository.swift`:

```swift
import Foundation

protocol AssociationRepository: Sendable {
    func loadRows() async throws -> [ExtensionAssociationRow]
    func refreshRows(for normalizedExtensions: [String]) async throws -> [ExtensionAssociationRow]
    func loadAppChoices() async throws -> [AppDescriptor]
    func addUserExtension(_ rawExtension: String) async throws -> String
}
```

Write `Sources/OpenWithGUIApp/Services/AssociationWriter.swift`:

```swift
import Foundation

struct AssociationWriteResult: Equatable, Sendable {
    let normalizedExtension: String
    let errorMessage: String?
}

protocol AssociationWriter: Sendable {
    func setDefaultApp(_ app: AppDescriptor, for normalizedExtensions: [String]) async throws -> [AssociationWriteResult]
}
```

Write `Sources/OpenWithGUIApp/Services/LaunchServicesClient.swift`:

```swift
import CoreServices
import Foundation
import UniformTypeIdentifiers

struct LaunchServicesClient: Sendable {
    var defaultAppURLHandler: @Sendable (String) throws -> URL?
    var setDefaultHandlerHandler: @Sendable (String, String) throws -> Void
    var allHandlersHandler: @Sendable (String) -> [String]

    init(
        defaultAppURLHandler: @escaping @Sendable (String) throws -> URL?,
        setDefaultHandler: @escaping @Sendable (String, String) throws -> Void,
        allHandlersHandler: @escaping @Sendable (String) -> [String]
    ) {
        self.defaultAppURLHandler = defaultAppURLHandler
        self.setDefaultHandlerHandler = setDefaultHandler
        self.allHandlersHandler = allHandlersHandler
    }

    static let live = LaunchServicesClient(
        defaultAppURLHandler: { identifier in
            var error: Unmanaged<CFError>?
            let result = LSCopyDefaultApplicationURLForContentType(
                identifier as CFString,
                .all,
                &error
            )?.takeRetainedValue()

            if let error {
                throw error.takeRetainedValue() as Error
            }

            return result as URL?
        },
        setDefaultHandler: { bundleIdentifier, identifier in
            let status = LSSetDefaultRoleHandlerForContentType(
                identifier as CFString,
                .all,
                bundleIdentifier as CFString
            )

            guard status == noErr else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
        },
        allHandlersHandler: { identifier in
            guard let unmanaged = LSCopyAllRoleHandlersForContentType(identifier as CFString, .all) else {
                return []
            }

            return unmanaged.takeRetainedValue() as? [String] ?? []
        }
    )

    func defaultAppURL(for identifier: String) throws -> URL? {
        try defaultAppURLHandler(identifier)
    }

    func setDefaultHandler(bundleIdentifier: String, for identifier: String) throws {
        try setDefaultHandlerHandler(bundleIdentifier, identifier)
    }

    func allHandlerBundleIdentifiers(for identifier: String) -> [String] {
        allHandlersHandler(identifier)
    }
}
```

- [ ] **Step 3: Implement the live repository and writer**

Write `Sources/OpenWithGUIApp/Services/SystemAssociationRepository.swift`:

```swift
import Foundation
import UniformTypeIdentifiers

struct SystemAssociationRepository: AssociationRepository {
    struct ScannerAdapter: Sendable {
        var scanHandler: @Sendable () -> InstalledAppCatalog

        init(scanHandler: @escaping @Sendable () -> InstalledAppCatalog) {
            self.scanHandler = scanHandler
        }

        static let live = ScannerAdapter {
            AppCatalogScanner().scan()
        }
    }

    struct UserStoreAdapter: Sendable {
        var loadHandler: @Sendable () throws -> Set<String>
        var addHandler: @Sendable (String) throws -> Void

        init(
            loadHandler: @escaping @Sendable () throws -> Set<String>,
            addHandler: @escaping @Sendable (String) throws -> Void
        ) {
            self.loadHandler = loadHandler
            self.addHandler = addHandler
        }

        static let live = UserStoreAdapter(
            loadHandler: { try UserAddedExtensionStore().load() },
            addHandler: { try UserAddedExtensionStore().add($0) }
        )
    }

    let scanner: ScannerAdapter
    let launchServices: LaunchServicesClient
    let userStore: UserStoreAdapter

    func loadRows() async throws -> [ExtensionAssociationRow] {
        try await rows(for: nil)
    }

    func refreshRows(for normalizedExtensions: [String]) async throws -> [ExtensionAssociationRow] {
        try await rows(for: Set(normalizedExtensions))
    }

    func loadAppChoices() async throws -> [AppDescriptor] {
        scanner.scanHandler().allApps
    }

    func addUserExtension(_ rawExtension: String) async throws -> String {
        guard let normalized = ExtensionAssociationRow.normalize(rawExtension) else {
            throw UserAddedExtensionStore.ValidationError.invalidExtension
        }

        try userStore.addHandler(normalized)
        return normalized
    }

    private func rows(for filter: Set<String>?) async throws -> [ExtensionAssociationRow] {
        let catalog = scanner.scanHandler()
        let userAdded = try userStore.loadHandler()

        let allExtensions = Set(catalog.candidateAppsByExtension.keys).union(userAdded)
        let targetExtensions = filter.map { allExtensions.intersection($0) } ?? allExtensions

        let rows = targetExtensions.map { normalized -> ExtensionAssociationRow in
            let candidates = catalog.candidateAppsByExtension[normalized, default: []]
            let defaultApp = resolveDefaultApp(for: normalized, catalog: catalog)

            return ExtensionAssociationRow(
                rawExtension: normalized,
                currentDefaultApp: defaultApp,
                candidateApps: candidates,
                isUserAdded: userAdded.contains(normalized)
            )
        }

        return rows.sorted { $0.normalizedExtension < $1.normalizedExtension }
    }

    private func resolveDefaultApp(for normalizedExtension: String, catalog: InstalledAppCatalog) -> AppDescriptor? {
        guard let identifier = UTType(filenameExtension: normalizedExtension)?.identifier,
              let url = try? launchServices.defaultAppURL(for: identifier) else {
            return nil
        }

        let bundle = Bundle(url: url)
        let bundleIdentifier = bundle?.bundleIdentifier ?? "unknown.\(normalizedExtension)"
        let displayName = FileManager.default.displayName(atPath: url.path)
        let knownApp = catalog.allApps.first(where: { $0.bundleIdentifier == bundleIdentifier })

        return knownApp ?? AppDescriptor(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            appURL: url,
            isAvailable: FileManager.default.fileExists(atPath: url.path)
        )
    }
}
```

Write `Sources/OpenWithGUIApp/Services/SystemAssociationWriter.swift`:

```swift
import Foundation
import UniformTypeIdentifiers

struct SystemAssociationWriter: AssociationWriter {
    let launchServices: LaunchServicesClient
    let typeIdentifierResolver: @Sendable (String) -> String?

    init(
        launchServices: LaunchServicesClient = .live,
        typeIdentifierResolver: @escaping @Sendable (String) -> String? = { normalizedExtension in
            UTType(filenameExtension: normalizedExtension)?.identifier
        }
    ) {
        self.launchServices = launchServices
        self.typeIdentifierResolver = typeIdentifierResolver
    }

    func setDefaultApp(_ app: AppDescriptor, for normalizedExtensions: [String]) async throws -> [AssociationWriteResult] {
        normalizedExtensions.map { normalized in
            guard let identifier = typeIdentifierResolver(normalized) else {
                return AssociationWriteResult(
                    normalizedExtension: normalized,
                    errorMessage: "macOS does not recognize this extension yet."
                )
            }

            do {
                try launchServices.setDefaultHandler(bundleIdentifier: app.bundleIdentifier, for: identifier)
                return AssociationWriteResult(normalizedExtension: normalized, errorMessage: nil)
            } catch {
                return AssociationWriteResult(
                    normalizedExtension: normalized,
                    errorMessage: "macOS did not accept this default-app change."
                )
            }
        }
    }
}
```

- [ ] **Step 4: Run repository and writer tests**

Run:

```bash
swift test --filter SystemAssociationRepositoryTests
swift test --filter SystemAssociationWriterTests
```

Expected:

- the repository test shows scanned and user-added rows merged in sorted order
- the writer test shows a recognized extension succeeding and an unknown extension failing cleanly

- [ ] **Step 5: Commit the system association layer**

Run:

```bash
git add Sources/OpenWithGUIApp/Services Tests/OpenWithGUIAppTests/Services
git commit -m "feat: add Launch Services association services"
```

Expected: one commit containing the repository, writer, and Launch Services wrapper.

## Task 4: Implement the view model for loading, search, selection, add, and batch apply

**Files:**
- Create: `Sources/OpenWithGUIApp/ViewModels/AssociationListViewModel.swift`
- Test: `Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift`

- [ ] **Step 1: Write failing tests for the view model**

Write `Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift`:

```swift
import Foundation
import Testing
@testable import OpenWithGUIApp

@MainActor
struct AssociationListViewModelTests {
    @Test
    func filtersRowsByExtensionAndAppName() async throws {
        let textEdit = AppDescriptor(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            appURL: URL(fileURLWithPath: "/Applications/TextEdit.app"),
            isAvailable: true
        )

        let repository = RepositoryStub(
            rows: [
                ExtensionAssociationRow(rawExtension: "json", currentDefaultApp: textEdit, candidateApps: [textEdit]),
                ExtensionAssociationRow(rawExtension: "png", currentDefaultApp: nil, candidateApps: [])
            ],
            apps: [textEdit]
        )

        let viewModel = AssociationListViewModel(
            repository: repository,
            writer: WriterStub(results: [])
        )

        await viewModel.load()
        viewModel.searchText = "textedit"

        #expect(viewModel.visibleRows.map(\.normalizedExtension) == ["json"])
    }

    @Test
    func batchApplyMarksRefreshMismatchAsPendingVerification() async throws {
        let textEdit = AppDescriptor(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            appURL: URL(fileURLWithPath: "/Applications/TextEdit.app"),
            isAvailable: true
        )

        let repository = RepositoryStub(
            rows: [ExtensionAssociationRow(rawExtension: "json", currentDefaultApp: nil, candidateApps: [textEdit])],
            apps: [textEdit],
            refreshRows: [ExtensionAssociationRow(rawExtension: "json", currentDefaultApp: nil, candidateApps: [textEdit])]
        )

        let writer = WriterStub(results: [
            AssociationWriteResult(normalizedExtension: "json", errorMessage: nil)
        ])

        let viewModel = AssociationListViewModel(repository: repository, writer: writer)
        await viewModel.load()
        viewModel.selection = ["json"]

        await viewModel.apply(app: textEdit, to: ["json"])

        #expect(viewModel.rows.first?.statusFlags.contains(.writePendingVerification) == true)
    }
}

private struct RepositoryStub: AssociationRepository, Sendable {
    var rows: [ExtensionAssociationRow]
    var apps: [AppDescriptor]
    var refreshRows: [ExtensionAssociationRow]? = nil

    func loadRows() async throws -> [ExtensionAssociationRow] { rows }
    func refreshRows(for normalizedExtensions: [String]) async throws -> [ExtensionAssociationRow] { refreshRows ?? rows }
    func loadAppChoices() async throws -> [AppDescriptor] { apps }
    func addUserExtension(_ rawExtension: String) async throws -> String {
        ExtensionAssociationRow.normalize(rawExtension) ?? rawExtension
    }
}

private struct WriterStub: AssociationWriter, Sendable {
    var results: [AssociationWriteResult]

    func setDefaultApp(_ app: AppDescriptor, for normalizedExtensions: [String]) async throws -> [AssociationWriteResult] {
        results
    }
}
```

- [ ] **Step 2: Implement the view model**

Write `Sources/OpenWithGUIApp/ViewModels/AssociationListViewModel.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AssociationListViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    enum Sort: String {
        case extensionAscending
        case extensionDescending
        case defaultAppAscending
    }

    private let repository: AssociationRepository
    private let writer: AssociationWriter

    var rows: [ExtensionAssociationRow] = []
    var availableApps: [AppDescriptor] = []
    var selection: Set<String> = []
    var searchText = ""
    var sort: Sort = .extensionAscending
    var phase: Phase = .idle
    var lastBatchSummary: String?

    init(repository: AssociationRepository, writer: AssociationWriter) {
        self.repository = repository
        self.writer = writer
    }

    var visibleRows: [ExtensionAssociationRow] {
        let filtered = rows.filter { row in
            if searchText.isEmpty { return true }
            let query = searchText.lowercased()
            return row.displayExtension.lowercased().contains(query)
                || (row.currentDefaultApp?.displayName.lowercased().contains(query) ?? false)
                || row.candidateApps.contains(where: { $0.displayName.lowercased().contains(query) })
        }

        switch sort {
        case .extensionAscending:
            return filtered.sorted { $0.normalizedExtension < $1.normalizedExtension }
        case .extensionDescending:
            return filtered.sorted { $0.normalizedExtension > $1.normalizedExtension }
        case .defaultAppAscending:
            return filtered.sorted {
                ($0.currentDefaultApp?.displayName ?? "") < ($1.currentDefaultApp?.displayName ?? "")
            }
        }
    }

    var selectedRows: [ExtensionAssociationRow] {
        rows.filter { selection.contains($0.normalizedExtension) }
    }

    var primarySelectedRow: ExtensionAssociationRow? {
        guard selection.count == 1 else { return nil }
        return rows.first(where: { selection.contains($0.normalizedExtension) })
    }

    func load() async {
        phase = .loading

        do {
            async let loadedRows = repository.loadRows()
            async let apps = repository.loadAppChoices()

            rows = try await loadedRows
            availableApps = try await apps
            phase = .loaded
        } catch {
            phase = .failed(message: "Unable to load the current extension associations.")
        }
    }

    func addExtension(_ rawExtension: String, app: AppDescriptor) async {
        do {
            let normalized = try await repository.addUserExtension(rawExtension)
            await apply(app: app, to: [normalized])
        } catch {
            phase = .failed(message: "Enter a valid extension before assigning an app.")
        }
    }

    func apply(app: AppDescriptor, to normalizedExtensions: [String]) async {
        guard !normalizedExtensions.isEmpty else { return }

        do {
            let writeResults = try await writer.setDefaultApp(app, for: normalizedExtensions)
            let refreshed = try await repository.refreshRows(for: normalizedExtensions)
            merge(refreshedRows: refreshed, writeResults: writeResults, targetApp: app)
            lastBatchSummary = summary(for: writeResults)
        } catch {
            phase = .failed(message: "Unable to update the selected extensions.")
        }
    }

    private func merge(
        refreshedRows: [ExtensionAssociationRow],
        writeResults: [AssociationWriteResult],
        targetApp: AppDescriptor
    ) {
        let writeResultsByExtension = Dictionary(uniqueKeysWithValues: writeResults.map { ($0.normalizedExtension, $0) })
        let refreshedByExtension = Dictionary(uniqueKeysWithValues: refreshedRows.map { ($0.normalizedExtension, $0) })

        let mergedExistingRows = rows.map { existing in
            guard let refreshed = refreshedByExtension[existing.normalizedExtension] else {
                return existing
            }

            guard let writeResult = writeResultsByExtension[existing.normalizedExtension] else {
                return refreshed
            }

            if let errorMessage = writeResult.errorMessage {
                return refreshed.withOperationResult(.failed(message: errorMessage))
            }

            if refreshed.currentDefaultApp?.bundleIdentifier != targetApp.bundleIdentifier {
                return refreshed.withOperationResult(
                    .pendingVerification(message: "The change was submitted, but the refreshed system state does not yet confirm it.")
                )
            }

            return refreshed.withOperationResult(.succeeded(message: "Default app updated."))
        }

        let missingRows = refreshedRows
            .filter { refreshedByExtension[$0.normalizedExtension] != nil }
            .filter { refreshed in
                !mergedExistingRows.contains(where: { $0.normalizedExtension == refreshed.normalizedExtension })
            }

        rows = (mergedExistingRows + missingRows).sorted { $0.normalizedExtension < $1.normalizedExtension }
    }

    private func summary(for writeResults: [AssociationWriteResult]) -> String {
        let successCount = writeResults.filter { $0.errorMessage == nil }.count
        let failureCount = writeResults.count - successCount
        return "\(successCount) succeeded, \(failureCount) failed"
    }
}
```

- [ ] **Step 3: Run the view model tests**

Run:

```bash
swift test --filter AssociationListViewModelTests
```

Expected: the filtering and refresh-mismatch tests pass.

- [ ] **Step 4: Add one more test for add-extension behavior**

Update `Tests/OpenWithGUIAppTests/ViewModels/AssociationListViewModelTests.swift` with:

```swift
    @Test
    func addExtensionNormalizesInputBeforeWriting() async throws {
        let textEdit = AppDescriptor(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            appURL: URL(fileURLWithPath: "/Applications/TextEdit.app"),
            isAvailable: true
        )

        let repository = RepositoryStub(
            rows: [],
            apps: [textEdit],
            refreshRows: [ExtensionAssociationRow(rawExtension: "json", currentDefaultApp: textEdit, candidateApps: [textEdit], isUserAdded: true)]
        )

        let writer = WriterStub(results: [
            AssociationWriteResult(normalizedExtension: "json", errorMessage: nil)
        ])

        let viewModel = AssociationListViewModel(repository: repository, writer: writer)
        await viewModel.load()
        await viewModel.addExtension(".JSON", app: textEdit)

        #expect(viewModel.rows.first?.normalizedExtension == "json")
        #expect(viewModel.rows.first?.statusFlags.contains(.userAddedRule) == true)
    }
```

Run:

```bash
swift test --filter AssociationListViewModelTests
```

Expected: the new add-extension test passes with the existing tests.

- [ ] **Step 5: Commit the view model**

Run:

```bash
git add Sources/OpenWithGUIApp/ViewModels Tests/OpenWithGUIAppTests/ViewModels
git commit -m "feat: add association list view model"
```

Expected: one commit containing the observable view model and tests.

## Task 5: Build the SwiftUI table manager UI

**Files:**
- Modify: `Sources/OpenWithGUIApp/Views/RootView.swift`
- Create: `Sources/OpenWithGUIApp/Views/AssociationTableView.swift`
- Create: `Sources/OpenWithGUIApp/Views/AssociationDetailSidebar.swift`
- Create: `Sources/OpenWithGUIApp/Views/BatchActionSidebar.swift`
- Create: `Sources/OpenWithGUIApp/Views/AppPickerSheet.swift`
- Create: `Sources/OpenWithGUIApp/Views/AddExtensionSheet.swift`

- [ ] **Step 1: Replace the temporary root view with the split layout**

Write `Sources/OpenWithGUIApp/Views/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @State private var showingBatchPicker = false
    @State private var showingAddSheet = false
    @State private var showingSinglePicker = false
    @State private var singleSelectionExtension: String?
    @Bindable var viewModel: AssociationListViewModel

    var body: some View {
        HSplitView {
            AssociationTableView(viewModel: viewModel)
                .frame(minWidth: 760)

            sidebar
                .frame(minWidth: 320, idealWidth: 360)
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar)
        .toolbar {
            ToolbarItemGroup {
                Button("Refresh") {
                    Task { await viewModel.load() }
                }

                Button("Set Selected to App") {
                    showingBatchPicker = true
                }
                .disabled(viewModel.selection.isEmpty)

                Button("Add Extension") {
                    showingAddSheet = true
                }
            }
        }
        .sheet(isPresented: $showingBatchPicker) {
            AppPickerSheet(
                apps: viewModel.availableApps,
                title: "Set Selected Extensions",
                onSelect: { app in
                    Task { await viewModel.apply(app: app, to: Array(viewModel.selection).sorted()) }
                    showingBatchPicker = false
                }
            )
        }
        .sheet(isPresented: $showingSinglePicker) {
            AppPickerSheet(
                apps: viewModel.availableApps,
                title: "Set Default App for .\(singleSelectionExtension ?? "")",
                onSelect: { app in
                    guard let normalizedExtension = singleSelectionExtension else { return }
                    Task { await viewModel.apply(app: app, to: [normalizedExtension]) }
                    singleSelectionExtension = nil
                    showingSinglePicker = false
                }
            )
        }
        .sheet(isPresented: $showingAddSheet) {
            AddExtensionSheet(
                apps: viewModel.availableApps,
                onSubmit: { rawExtension, app in
                    Task { await viewModel.addExtension(rawExtension, app: app) }
                    showingAddSheet = false
                }
            )
        }
        .task {
            if viewModel.phase == .idle {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if viewModel.selection.count > 1 {
            BatchActionSidebar(
                selectionCount: viewModel.selection.count,
                lastBatchSummary: viewModel.lastBatchSummary,
                onChooseApp: { showingBatchPicker = true }
            )
        } else if let row = viewModel.primarySelectedRow {
            AssociationDetailSidebar(
                row: row,
                onChooseApp: {
                    singleSelectionExtension = row.normalizedExtension
                    showingSinglePicker = true
                }
            )
        } else {
            ContentUnavailableView(
                "Select an Extension",
                systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                description: Text("Choose one row to inspect its default app and candidates.")
            )
        }
    }
}
```

- [ ] **Step 2: Implement the table and sidebars**

Write `Sources/OpenWithGUIApp/Views/AssociationTableView.swift`:

```swift
import SwiftUI

struct AssociationTableView: View {
    @Bindable var viewModel: AssociationListViewModel

    var body: some View {
        Table(viewModel.visibleRows, selection: $viewModel.selection) {
            TableColumn("Extension") { row in
                Text(row.displayExtension)
                    .font(.system(.body, design: .monospaced))
            }

            TableColumn("Default App") { row in
                Text(row.currentDefaultApp?.displayName ?? "Not Set")
                    .foregroundStyle(row.currentDefaultApp == nil ? .secondary : .primary)
            }

            TableColumn("Candidate Apps") { row in
                Text("\(row.candidateApps.count)")
            }

            TableColumn("Status") { row in
                Text(row.statusFlags.map(\.rawValue).joined(separator: ", "))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
```

Write `Sources/OpenWithGUIApp/Views/AssociationDetailSidebar.swift`:

```swift
import AppKit
import SwiftUI

struct AssociationDetailSidebar: View {
    let row: ExtensionAssociationRow
    let onChooseApp: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(row.displayExtension)
                    .font(.largeTitle.bold())

                Button("Change Default App") {
                    onChooseApp()
                }

                GroupBox("Current Default App") {
                    if let app = row.currentDefaultApp {
                        AppSummaryView(app: app)
                    } else {
                        Text("No default app is currently set for this extension.")
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox("Candidate Apps") {
                    if row.candidateApps.isEmpty {
                        Text("No candidate apps were discovered for this extension.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(row.candidateApps) { app in
                                AppSummaryView(app: app)
                            }
                        }
                    }
                }

                if case let .failed(message) = row.lastOperationResult {
                    Text(message).foregroundStyle(.red)
                } else if case let .pendingVerification(message) = row.lastOperationResult {
                    Text(message).foregroundStyle(.orange)
                } else if case let .succeeded(message) = row.lastOperationResult {
                    Text(message).foregroundStyle(.green)
                }
            }
            .padding()
        }
    }
}

private struct AppSummaryView: View {
    let app: AppDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path))
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName)
                    .font(.headline)
                Text(app.bundleIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(app.appURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}
```

Write `Sources/OpenWithGUIApp/Views/BatchActionSidebar.swift`:

```swift
import SwiftUI

struct BatchActionSidebar: View {
    let selectionCount: Int
    let lastBatchSummary: String?
    let onChooseApp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Batch Update")
                .font(.title.bold())

            Text("\(selectionCount) extensions selected")
                .font(.headline)

            Button("Choose Target App") {
                onChooseApp()
            }

            if let lastBatchSummary {
                Text(lastBatchSummary)
                    .font(.body.monospaced())
            }

            Spacer()
        }
        .padding()
    }
}
```

- [ ] **Step 3: Implement the app picker and add-extension sheet**

Write `Sources/OpenWithGUIApp/Views/AppPickerSheet.swift`:

```swift
import AppKit
import SwiftUI

struct AppPickerSheet: View {
    let apps: [AppDescriptor]
    let title: String
    let onSelect: (AppDescriptor) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.bold())

            TextField("Search apps", text: $searchText)

            List(filteredApps) { app in
                Button {
                    onSelect(app)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path))
                            .resizable()
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.displayName)
                            Text(app.bundleIdentifier)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 320)
        }
        .padding()
        .frame(width: 520, height: 480)
    }

    private var filteredApps: [AppDescriptor] {
        if searchText.isEmpty {
            return apps
        }

        let query = searchText.lowercased()
        return apps.filter {
            $0.displayName.lowercased().contains(query)
                || $0.bundleIdentifier.lowercased().contains(query)
        }
    }
}
```

Write `Sources/OpenWithGUIApp/Views/AddExtensionSheet.swift`:

```swift
import SwiftUI

struct AddExtensionSheet: View {
    let apps: [AppDescriptor]
    let onSubmit: (String, AppDescriptor) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rawExtension = ""
    @State private var selectedAppID: AppDescriptor.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Extension")
                .font(.title2.bold())

            TextField("json", text: $rawExtension)
                .textFieldStyle(.roundedBorder)

            Picker("Default App", selection: $selectedAppID) {
                Text("Choose an app").tag(AppDescriptor.ID?.none)
                ForEach(apps) { app in
                    Text(app.displayName).tag(AppDescriptor.ID?.some(app.id))
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Add") {
                    guard let selectedApp = apps.first(where: { $0.id == selectedAppID }) else {
                        return
                    }

                    onSubmit(rawExtension, selectedApp)
                    dismiss()
                }
                .disabled(ExtensionAssociationRow.normalize(rawExtension) == nil || selectedAppID == nil)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
```

- [ ] **Step 4: Run a full build and the existing tests**

Run:

```bash
swift test
swift build
```

Expected:

- all existing tests still pass
- the UI target compiles with the new SwiftUI views

- [ ] **Step 5: Commit the UI**

Run:

```bash
git add Sources/OpenWithGUIApp/Views
git commit -m "feat: add table manager interface"
```

Expected: one commit containing the split view, table, sidebars, and sheets.

## Task 6: Wire the live app container and final verification

**Files:**
- Modify: `Sources/OpenWithGUIApp/OpenWithGUIApp.swift`
- Modify: `Sources/OpenWithGUIApp/Views/RootView.swift`

- [ ] **Step 1: Inject the live repository and writer into the app**

Update `Sources/OpenWithGUIApp/OpenWithGUIApp.swift`:

```swift
import SwiftUI

@main
struct OpenWithGUIApp: App {
    @State private var viewModel = AssociationListViewModel(
        repository: SystemAssociationRepository(
            scanner: .live,
            launchServices: .live,
            userStore: .live
        ),
        writer: SystemAssociationWriter()
    )

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
        .defaultSize(width: 1200, height: 760)
    }
}
```

- [ ] **Step 2: Add an explicit load-state fallback to the root view**

Update `Sources/OpenWithGUIApp/Views/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @State private var showingBatchPicker = false
    @State private var showingAddSheet = false
    @State private var showingSinglePicker = false
    @State private var singleSelectionExtension: String?
    @Bindable var viewModel: AssociationListViewModel

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .loading:
                ProgressView("Loading extension associations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                ContentUnavailableView(
                    "Unable to Load Associations",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded:
                content
            }
        }
        .task {
            if viewModel.phase == .idle {
                await viewModel.load()
            }
        }
    }

    private var content: some View {
        HSplitView {
            AssociationTableView(viewModel: viewModel)
                .frame(minWidth: 760)

            sidebar
                .frame(minWidth: 320, idealWidth: 360)
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar)
        .toolbar {
            ToolbarItemGroup {
                Button("Refresh") {
                    Task { await viewModel.load() }
                }

                Button("Set Selected to App") {
                    showingBatchPicker = true
                }
                .disabled(viewModel.selection.isEmpty)

                Button("Add Extension") {
                    showingAddSheet = true
                }
            }
        }
        .sheet(isPresented: $showingBatchPicker) {
            AppPickerSheet(
                apps: viewModel.availableApps,
                title: "Set Selected Extensions",
                onSelect: { app in
                    Task { await viewModel.apply(app: app, to: Array(viewModel.selection).sorted()) }
                    showingBatchPicker = false
                }
            )
        }
        .sheet(isPresented: $showingSinglePicker) {
            AppPickerSheet(
                apps: viewModel.availableApps,
                title: "Set Default App for .\(singleSelectionExtension ?? "")",
                onSelect: { app in
                    guard let normalizedExtension = singleSelectionExtension else { return }
                    Task { await viewModel.apply(app: app, to: [normalizedExtension]) }
                    singleSelectionExtension = nil
                    showingSinglePicker = false
                }
            )
        }
        .sheet(isPresented: $showingAddSheet) {
            AddExtensionSheet(
                apps: viewModel.availableApps,
                onSubmit: { rawExtension, app in
                    Task { await viewModel.addExtension(rawExtension, app: app) }
                    showingAddSheet = false
                }
            )
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if viewModel.selection.count > 1 {
            BatchActionSidebar(
                selectionCount: viewModel.selection.count,
                lastBatchSummary: viewModel.lastBatchSummary,
                onChooseApp: { showingBatchPicker = true }
            )
        } else if let row = viewModel.primarySelectedRow {
            AssociationDetailSidebar(
                row: row,
                onChooseApp: {
                    singleSelectionExtension = row.normalizedExtension
                    showingSinglePicker = true
                }
            )
        } else {
            ContentUnavailableView(
                "Select an Extension",
                systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                description: Text("Choose one row to inspect its default app and candidates.")
            )
        }
    }
}
```

- [ ] **Step 3: Run the full verification pass**

Run:

```bash
swift test
swift build
swift run OpenWithGUI
```

Expected:

- `swift test` passes all test targets
- `swift build` succeeds
- `swift run OpenWithGUI` launches the macOS window and shows the table manager UI

- [ ] **Step 4: Perform manual validation on real extensions**

Validate these cases manually in the running app:

```text
1. Search for `.json`, `.md`, and `.png`.
2. Confirm each row shows a default app and candidate list when available.
3. Multi-select at least two extensions and set them to the same app.
4. Re-open the rows and confirm the default app now matches the chosen app or shows pending verification.
5. Add a user extension like `.sampleext` and confirm it appears in the table with the `userAddedRule` state.
```

Expected: the UI reflects the changed state immediately after refresh and surfaces any write failures clearly.

- [ ] **Step 5: Commit the wired app**

Run:

```bash
git add Sources Package.swift Tests
git commit -m "feat: wire live extension association manager"
```

Expected: one final commit with the live app wiring and verified UI.
