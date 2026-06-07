import Foundation

struct VoiceNote: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var plainText: String
    var contentFilename: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        plainText: String = "",
        contentFilename: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.plainText = plainText
        self.contentFilename = contentFilename ?? "\(id.uuidString).rtf"
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled note" : trimmed
    }

    var preview: String {
        let collapsed = plainText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? "No content yet" : String(collapsed.prefix(96))
    }

    static func inferredTitle(from text: String) -> String {
        let firstLine = text
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstLine, !firstLine.isEmpty else {
            return "Untitled note"
        }

        return String(firstLine.prefix(64))
    }
}
