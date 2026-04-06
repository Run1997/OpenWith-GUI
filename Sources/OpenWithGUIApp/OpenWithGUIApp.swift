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
