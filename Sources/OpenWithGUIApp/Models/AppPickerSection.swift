import Foundation

struct AppPickerSection: Identifiable, Equatable {
    let title: String
    let apps: [AppDescriptor]

    var id: String { title }

    static func makeSections(
        apps: [AppDescriptor],
        candidateApps: [AppDescriptor],
        searchText: String
    ) -> [AppPickerSection] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let filteredApps = apps.filter { app in
            guard !query.isEmpty else {
                return true
            }

            return app.displayName.lowercased().contains(query)
                || app.bundleIdentifier.lowercased().contains(query)
        }

        let filteredCandidates = candidateApps.filter { candidate in
            filteredApps.contains(candidate)
        }

        let candidateIDs = Set(filteredCandidates.map(\.id))
        let otherApps = filteredApps.filter { !candidateIDs.contains($0.id) }

        var sections: [AppPickerSection] = []

        if !filteredCandidates.isEmpty {
            sections.append(AppPickerSection(title: "Candidate Apps", apps: filteredCandidates))
        }

        if !otherApps.isEmpty {
            sections.append(AppPickerSection(title: "Other Apps", apps: otherApps))
        }

        return sections
    }
}
