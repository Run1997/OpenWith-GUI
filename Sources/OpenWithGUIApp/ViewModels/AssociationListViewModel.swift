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
    var selectedDefaultAppBundleIdentifier: String?
    var searchText = ""
    var sort: Sort = .extensionAscending
    var phase: Phase = .idle
    var lastBatchSummary: String?

    init(repository: AssociationRepository, writer: AssociationWriter) {
        self.repository = repository
        self.writer = writer
    }

    var visibleRows: [ExtensionAssociationRow] {
        let filteredRows = rows.filter { row in
            guard !searchText.isEmpty else {
                return true
            }

            let query = searchText.lowercased()
            return row.displayExtension.lowercased().contains(query)
                || (row.currentDefaultApp?.displayName.lowercased().contains(query) ?? false)
                || row.candidateApps.contains(where: { $0.displayName.lowercased().contains(query) })
        }

        let defaultAppFilteredRows = filteredRows.filter { row in
            guard let selectedDefaultAppBundleIdentifier else {
                return true
            }

            return row.currentDefaultApp?.bundleIdentifier == selectedDefaultAppBundleIdentifier
        }

        switch sort {
        case .extensionAscending:
            return defaultAppFilteredRows.sorted { $0.normalizedExtension < $1.normalizedExtension }
        case .extensionDescending:
            return defaultAppFilteredRows.sorted { $0.normalizedExtension > $1.normalizedExtension }
        case .defaultAppAscending:
            return defaultAppFilteredRows.sorted {
                ($0.currentDefaultApp?.displayName ?? "") < ($1.currentDefaultApp?.displayName ?? "")
            }
        }
    }

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

    var selectedRows: [ExtensionAssociationRow] {
        rows.filter { selection.contains($0.normalizedExtension) }
    }

    var primarySelectedRow: ExtensionAssociationRow? {
        guard selection.count == 1 else {
            return nil
        }

        return rows.first(where: { selection.contains($0.normalizedExtension) })
    }

    func selectFirstRowIfNeeded() {
        guard selection.isEmpty, let firstRow = visibleRows.first else {
            return
        }

        selection = [firstRow.normalizedExtension]
    }

    func applyDefaultAppFilter(_ app: AppDescriptor) {
        selectedDefaultAppBundleIdentifier = app.bundleIdentifier
        reconcileSelectionWithVisibleRows()
    }

    func clearDefaultAppFilter() {
        selectedDefaultAppBundleIdentifier = nil
        reconcileSelectionWithVisibleRows()
    }

    func load() async {
        phase = .loading

        do {
            async let loadedRows = repository.loadRows()
            async let loadedApps = repository.loadAppChoices()

            rows = try await loadedRows
            availableApps = try await loadedApps
            phase = .loaded
        } catch {
            phase = .failed(message: "Unable to load the current extension associations.")
        }
    }

    func addExtension(_ rawExtension: String, app: AppDescriptor) async {
        do {
            let normalizedExtension = try await repository.addUserExtension(rawExtension)
            await apply(app: app, to: [normalizedExtension])
        } catch {
            phase = .failed(message: "Enter a valid extension before assigning an app.")
        }
    }

    func apply(app: AppDescriptor, to normalizedExtensions: [String]) async {
        guard !normalizedExtensions.isEmpty else {
            return
        }

        do {
            let writeResults = try await writer.setDefaultApp(app, for: normalizedExtensions)
            let refreshedRows = try await repository.refreshRows(for: normalizedExtensions)
            merge(refreshedRows: refreshedRows, writeResults: writeResults, targetApp: app)
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
        let refreshedByExtension = Dictionary(uniqueKeysWithValues: refreshedRows.map { ($0.normalizedExtension, $0) })
        let writeResultsByExtension = Dictionary(uniqueKeysWithValues: writeResults.map { ($0.normalizedExtension, $0) })

        let mergedExistingRows = rows.map { existingRow in
            guard let refreshedRow = refreshedByExtension[existingRow.normalizedExtension] else {
                return existingRow
            }

            guard let writeResult = writeResultsByExtension[existingRow.normalizedExtension] else {
                return refreshedRow
            }

            if let errorMessage = writeResult.errorMessage {
                return refreshedRow.withOperationResult(.failed(message: errorMessage))
            }

            if refreshedRow.currentDefaultApp?.bundleIdentifier != targetApp.bundleIdentifier {
                return refreshedRow.withOperationResult(
                    .pendingVerification(message: "The change was submitted, but the refreshed system state does not yet confirm it.")
                )
            }

            return refreshedRow.withOperationResult(.succeeded(message: "Default app updated."))
        }

        let newRows = refreshedRows.filter { refreshedRow in
            !mergedExistingRows.contains(where: { $0.normalizedExtension == refreshedRow.normalizedExtension })
        }.map { refreshedRow in
            guard let writeResult = writeResultsByExtension[refreshedRow.normalizedExtension] else {
                return refreshedRow
            }

            if let errorMessage = writeResult.errorMessage {
                return refreshedRow.withOperationResult(.failed(message: errorMessage))
            }

            if refreshedRow.currentDefaultApp?.bundleIdentifier != targetApp.bundleIdentifier {
                return refreshedRow.withOperationResult(
                    .pendingVerification(message: "The change was submitted, but the refreshed system state does not yet confirm it.")
                )
            }

            return refreshedRow.withOperationResult(.succeeded(message: "Default app updated."))
        }

        rows = (mergedExistingRows + newRows).sorted { $0.normalizedExtension < $1.normalizedExtension }
    }

    private func summary(for writeResults: [AssociationWriteResult]) -> String {
        let successCount = writeResults.filter { $0.errorMessage == nil }.count
        let failureCount = writeResults.count - successCount
        return "\(successCount) succeeded, \(failureCount) failed"
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
}
