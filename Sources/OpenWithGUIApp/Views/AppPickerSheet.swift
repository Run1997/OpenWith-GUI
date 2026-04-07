import AppKit
import SwiftUI

struct AppPickerSheet: View {
    let apps: [AppDescriptor]
    let title: String
    let candidateApps: [AppDescriptor]
    let showsCandidateGrouping: Bool
    let leadingChoices: [AppPickerChoice]
    let onSelectChoice: (AppPickerChoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.bold())

            TextField("Search apps", text: $searchText)

            List {
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

                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.apps) { app in
                            Button {
                                onSelectChoice(.app(app))
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
                    }
                }
            }
            .frame(minHeight: 320)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 520, height: 480)
    }

    private var filteredLeadingChoices: [AppPickerChoice] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return leadingChoices.filter { choice in
            guard !query.isEmpty else {
                return true
            }

            return choice.title.lowercased().contains(query)
                || choice.subtitle.lowercased().contains(query)
        }
    }

    private var sections: [AppPickerSection] {
        if showsCandidateGrouping {
            return AppPickerSection.makeSections(
                apps: apps,
                candidateApps: candidateApps,
                searchText: searchText
            )
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredApps = apps.filter { app in
            guard !query.isEmpty else {
                return true
            }

            return app.displayName.lowercased().contains(query)
                || app.bundleIdentifier.lowercased().contains(query)
        }

        return filteredApps.isEmpty ? [] : [AppPickerSection(title: "Apps", apps: filteredApps)]
    }
}
