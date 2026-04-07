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
