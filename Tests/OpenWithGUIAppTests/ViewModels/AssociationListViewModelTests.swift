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
            refreshedRows: [ExtensionAssociationRow(rawExtension: "json", currentDefaultApp: nil, candidateApps: [textEdit])]
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
            refreshedRows: [
                ExtensionAssociationRow(
                    rawExtension: "json",
                    currentDefaultApp: textEdit,
                    candidateApps: [textEdit],
                    isUserAdded: true
                )
            ]
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
}

private struct RepositoryStub: AssociationRepository, Sendable {
    var rows: [ExtensionAssociationRow]
    var apps: [AppDescriptor]
    var refreshedRows: [ExtensionAssociationRow]? = nil

    func loadRows() async throws -> [ExtensionAssociationRow] {
        rows
    }

    func refreshRows(for normalizedExtensions: [String]) async throws -> [ExtensionAssociationRow] {
        refreshedRows ?? rows
    }

    func loadAppChoices() async throws -> [AppDescriptor] {
        apps
    }

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
