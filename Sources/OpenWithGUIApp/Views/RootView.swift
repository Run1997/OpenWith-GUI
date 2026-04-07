import SwiftUI
import Observation

struct RootView: View {
    @State private var hasAppliedInitialSelection = false
    @State private var showingBatchPicker = false
    @State private var showingAddSheet = false
    @State private var showingSinglePicker = false
    @State private var singleSelectionExtension: String?
    @State private var viewModel: AssociationListViewModel

    init(viewModel: AssociationListViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? AssociationListViewModel(
            repository: PreviewAssociationRepository(),
            writer: PreviewAssociationWriter()
        ))
    }

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
                if viewModel.visibleRows.isEmpty {
                    ContentUnavailableView(
                        "No Matching Extensions",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(
                            viewModel.selectedDefaultAppBundleIdentifier == nil
                                ? "No extensions are currently available."
                                : "No extensions are currently opened by the selected app. Use Default App -> All Apps to clear the filter."
                        )
                    )
                } else {
                    content
                }
            }
        }
        .task {
            if viewModel.phase == .idle {
                await viewModel.load()
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            guard newPhase == .loaded, !hasAppliedInitialSelection else {
                return
            }

            viewModel.selectFirstRowIfNeeded()
            hasAppliedInitialSelection = true
        }
    }

    private var content: some View {
        @Bindable var bindableViewModel = viewModel

        return HSplitView {
            AssociationTableView(viewModel: bindableViewModel)
                .frame(minWidth: 760)

            sidebar
                .frame(minWidth: 320, idealWidth: 360)
        }
        .searchable(text: $bindableViewModel.searchText, placement: .toolbar)
        .toolbar {
            ToolbarItemGroup {
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
                candidateApps: [],
                showsCandidateGrouping: false,
                leadingChoices: [],
                onSelectChoice: { choice in
                    guard let app = choice.appDescriptor else {
                        return
                    }

                    Task {
                        await viewModel.apply(app: app, to: Array(viewModel.selection).sorted())
                    }
                    showingBatchPicker = false
                }
            )
        }
        .sheet(isPresented: $showingSinglePicker, onDismiss: {
            singleSelectionExtension = nil
        }) {
            let selectedRow = viewModel.rows.first { $0.normalizedExtension == singleSelectionExtension }

            AppPickerSheet(
                apps: viewModel.availableApps,
                title: "Set Default App for .\(singleSelectionExtension ?? "")",
                candidateApps: selectedRow?.candidateApps ?? [],
                showsCandidateGrouping: true,
                leadingChoices: [],
                onSelectChoice: { choice in
                    guard let app = choice.appDescriptor else {
                        return
                    }

                    guard let normalizedExtension = singleSelectionExtension else {
                        return
                    }

                    Task {
                        await viewModel.apply(app: app, to: [normalizedExtension])
                    }
                    singleSelectionExtension = nil
                    showingSinglePicker = false
                }
            )
        }
        .sheet(isPresented: $showingAddSheet) {
            AddExtensionSheet(
                apps: viewModel.availableApps,
                onSubmit: { rawExtension, app in
                    Task {
                        await viewModel.addExtension(rawExtension, app: app)
                    }
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

private struct PreviewAssociationRepository: AssociationRepository {
    func loadRows() async throws -> [ExtensionAssociationRow] {
        []
    }

    func refreshRows(for normalizedExtensions: [String]) async throws -> [ExtensionAssociationRow] {
        []
    }

    func loadAppChoices() async throws -> [AppDescriptor] {
        []
    }

    func addUserExtension(_ rawExtension: String) async throws -> String {
        ExtensionAssociationRow.normalize(rawExtension) ?? rawExtension
    }
}

private struct PreviewAssociationWriter: AssociationWriter {
    func setDefaultApp(_ app: AppDescriptor, for normalizedExtensions: [String]) async throws -> [AssociationWriteResult] {
        []
    }
}
