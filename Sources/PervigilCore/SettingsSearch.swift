import Foundation

/// One searchable setting in the Settings window. Titles arrive already
/// localized, so search works in every language the app ships.
public struct SettingsSearchEntry: Equatable, Sendable, Identifiable {
    /// The Settings page, as its raw identifier.
    public var page: String
    /// The row or group to scroll to on that page.
    public var anchor: String
    public var title: String
    /// The group the row sits in, shown under the result.
    public var group: String?
    /// Extra words that should find this row ("pmset", "clamshell").
    public var keywords: [String]

    public var id: String { page + "/" + anchor + "/" + title }

    public init(page: String, anchor: String, title: String, group: String? = nil, keywords: [String] = []) {
        self.page = page
        self.anchor = anchor
        self.title = title
        self.group = group
        self.keywords = keywords
    }
}

public enum SettingsSearch {
    /// The entries matching `query`, best first: a title that starts with the
    /// query, then a word in the title that does, then a title containing it,
    /// then a group or keyword match. Case and diacritics are ignored. Each
    /// title appears once per page.
    public static func results(for query: String, in entries: [SettingsSearchEntry], limit: Int = 30) -> [SettingsSearchEntry] {
        let needle = normalize(query)
        guard !needle.isEmpty else { return [] }
        let ranked = entries.enumerated()
            .compactMap { index, entry -> (rank: Int, index: Int, entry: SettingsSearchEntry)? in
                guard let rank = rank(entry, needle) else { return nil }
                return (rank, index, entry)
            }
            .sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }
        var seen = Set<String>()
        var out: [SettingsSearchEntry] = []
        for item in ranked where seen.insert(item.entry.page + "/" + normalize(item.entry.title)).inserted {
            out.append(item.entry)
            if out.count == limit { break }
        }
        return out
    }

    /// Lower is better, `nil` is no match.
    static func rank(_ entry: SettingsSearchEntry, _ needle: String) -> Int? {
        let title = normalize(entry.title)
        if title.hasPrefix(needle) { return 0 }
        if title.split(separator: " ").contains(where: { $0.hasPrefix(needle) }) { return 1 }
        if title.contains(needle) { return 2 }
        if let group = entry.group, normalize(group).contains(needle) { return 3 }
        if entry.keywords.contains(where: { normalize($0).contains(needle) }) { return 4 }
        return nil
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
