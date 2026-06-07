import Foundation

enum AgentSource: String, CaseIterable, Hashable {
    case claudeCode = "claude-code"
    case codex = "codex"
    case geminiCLI = "gemini-cli"

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .geminiCLI: return "Gemini CLI"
        }
    }
}

struct AgentMessage: Equatable {
    let role: String
    let content: String
    var model: String?
    var toolNames: [String]
}

struct AgentSession: Equatable {
    let source: AgentSource
    let externalID: String
    let title: String?
    let folderPath: String?
    let folderDisplayName: String?
    let createdAt: Date
    let updatedAt: Date?
    let model: String?
    let toolNames: [String]
    let messages: [AgentMessage]

    var memoryItemID: String {
        "agent:\(source.rawValue):\(externalID)"
    }

    var transcriptText: String {
        messages
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { message in
                let role = message.role.uppercased()
                return "\(role): \(message.content)"
            }
            .joined(separator: "\n\n")
    }
}

struct AgentImportResult: Equatable {
    var sessions: [AgentSession] = []
    var skippedRecords: Int = 0
    var skippedFiles: Int = 0
    var sourceCounts: [AgentSource: Int] = [:]

    var importedSessionCount: Int { sessions.count }
    var skippedTotal: Int { skippedRecords + skippedFiles }
}

final class AgentSessionImportService {
    static let shared = AgentSessionImportService()

    private let fileManager: FileManager
    private let homeDirectory: URL

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    func importSessions() -> AgentImportResult {
        var result = AgentImportResult()
        append(imported: importClaudeCodeSessions(), to: &result, source: .claudeCode)
        append(imported: importCodexSessions(), to: &result, source: .codex)
        append(imported: importGeminiSessions(), to: &result, source: .geminiCLI)
        return result
    }

    private func append(imported: AgentImportResult, to result: inout AgentImportResult, source: AgentSource) {
        result.sessions.append(contentsOf: imported.sessions)
        result.skippedRecords += imported.skippedRecords
        result.skippedFiles += imported.skippedFiles
        result.sourceCounts[source, default: 0] += imported.sessions.count
    }
}

// MARK: - Claude Code

private extension AgentSessionImportService {
    func importClaudeCodeSessions() -> AgentImportResult {
        var result = AgentImportResult()
        let projectsURL = homeDirectory
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
        guard fileManager.fileExists(atPath: projectsURL.path) else { return result }

        let projectDirs = directoryContents(projectsURL).filter(isDirectory)
        for projectURL in projectDirs {
            let decodedFolder = decodeClaudeProjectFolder(projectURL.lastPathComponent)
            let index = loadClaudeSessionIndex(projectURL.appendingPathComponent("sessions-index.json"))
            let sessionFiles = directoryContents(projectURL).filter { $0.pathExtension == "jsonl" }

            for fileURL in sessionFiles {
                let externalID = fileURL.deletingPathExtension().lastPathComponent
                let indexEntry = index[externalID]
                let parsed = parseClaudeSession(fileURL: fileURL)
                guard !parsed.messages.isEmpty else {
                    result.skippedFiles += 1
                    result.skippedRecords += parsed.skippedRecords
                    continue
                }

                let rawFolder = parsed.folderPath
                    ?? string(indexEntry?["projectPath"])
                    ?? decodedFolder
                let normalizedFolder = FolderNormalizer.normalize(rawFolder)
                let title = parsed.title
                    ?? cleanPrompt(string(indexEntry?["firstPrompt"]))
                    ?? title(from: parsed.messages)
                let createdAt = parsed.createdAt
                    ?? date(from: indexEntry?["created"])
                    ?? fileDate(fileURL, key: .creationDateKey)
                    ?? Date()
                let updatedAt = parsed.updatedAt
                    ?? date(from: indexEntry?["modified"])
                    ?? fileDate(fileURL, key: .contentModificationDateKey)

                result.sessions.append(AgentSession(
                    source: .claudeCode,
                    externalID: externalID,
                    title: title,
                    folderPath: normalizedFolder.path,
                    folderDisplayName: normalizedFolder.displayName,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    model: parsed.model,
                    toolNames: Array(parsed.toolNames).sorted(),
                    messages: parsed.messages
                ))
                result.skippedRecords += parsed.skippedRecords
            }
        }

        return result
    }

    func parseClaudeSession(fileURL: URL) -> ParsedAgentSession {
        var parsed = ParsedAgentSession()
        for line in readLines(fileURL) {
            guard let object = parseJSONObject(line) else {
                parsed.skippedRecords += 1
                continue
            }

            if let cwd = string(object["cwd"]), parsed.folderPath == nil {
                parsed.folderPath = cwd
            }
            if let timestamp = date(from: object["timestamp"]), parsed.createdAt == nil {
                parsed.createdAt = timestamp
            }

            guard let type = string(object["type"]) else { continue }
            switch type {
            case "custom-title":
                parsed.title = cleanPrompt(string(object["customTitle"]))
            case "user":
                let text = extractClaudeText(from: object["message"]) ?? string(object["content"])
                appendMessage(role: "user", text: text, to: &parsed)
            case "assistant":
                let extracted = extractClaudeAssistant(from: object["message"])
                if let model = string((object["message"] as? JSONObject)?["model"]) {
                    parsed.model = model
                }
                parsed.toolNames.formUnion(extracted.toolNames)
                appendMessage(role: "assistant", text: extracted.text, model: parsed.model, tools: extracted.toolNames, to: &parsed)
            case "system":
                let text = extractClaudeText(from: object["message"]) ?? string(object["content"])
                appendMessage(role: "system", text: text, to: &parsed)
            default:
                continue
            }
        }
        return parsed
    }

    func loadClaudeSessionIndex(_ url: URL) -> [String: JSONObject] {
        guard
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? JSONObject,
            let entries = root["entries"] as? [JSONObject]
        else { return [:] }

        var index: [String: JSONObject] = [:]
        for entry in entries {
            if let sessionID = string(entry["sessionId"]) {
                index[sessionID] = entry
            }
        }
        return index
    }

    func decodeClaudeProjectFolder(_ encoded: String) -> String {
        let decoded = encoded.replacingOccurrences(of: "-", with: "/")
        return decoded.hasPrefix("/") ? decoded : "/" + decoded
    }
}

// MARK: - Codex

private extension AgentSessionImportService {
    func importCodexSessions() -> AgentImportResult {
        var result = AgentImportResult()
        let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : URL(fileURLWithPath: $0) }
            ?? homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        let roots = [
            codexHome.appendingPathComponent("sessions", isDirectory: true),
            codexHome.appendingPathComponent("archived_sessions", isDirectory: true),
        ]

        var seen = Set<String>()
        for root in roots where fileManager.fileExists(atPath: root.path) {
            for fileURL in recursiveFiles(root, fileExtension: "jsonl") {
                let parsed = parseCodexSession(fileURL: fileURL)
                result.skippedRecords += parsed.skippedRecords
                guard let meta = parsed.meta, !parsed.messages.isEmpty else {
                    result.skippedFiles += 1
                    continue
                }
                let externalID = meta.id ?? fileURL.deletingPathExtension().lastPathComponent
                guard seen.insert(externalID).inserted else { continue }

                let normalizedFolder = FolderNormalizer.normalize(meta.cwd)
                result.sessions.append(AgentSession(
                    source: .codex,
                    externalID: externalID,
                    title: parsed.title ?? title(from: parsed.messages),
                    folderPath: normalizedFolder.path,
                    folderDisplayName: normalizedFolder.displayName,
                    createdAt: meta.timestamp ?? fileDate(fileURL, key: .creationDateKey) ?? Date(),
                    updatedAt: fileDate(fileURL, key: .contentModificationDateKey),
                    model: parsed.model ?? meta.modelProvider,
                    toolNames: Array(parsed.toolNames).sorted(),
                    messages: parsed.messages
                ))
            }
        }

        return result
    }

    func parseCodexSession(fileURL: URL) -> ParsedCodexSession {
        var parsed = ParsedCodexSession()
        var currentModel: String?
        var currentAssistantParts: [String] = []
        var currentTools = Set<String>()
        var toolNamesByCallID: [String: String] = [:]

        func flushAssistant() {
            let text = currentAssistantParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty || !currentTools.isEmpty else { return }
            let content = text.isEmpty ? "[assistant activity]" : text
            parsed.messages.append(AgentMessage(
                role: "assistant",
                content: content,
                model: currentModel,
                toolNames: Array(currentTools).sorted()
            ))
            parsed.toolNames.formUnion(currentTools)
            currentAssistantParts = []
            currentTools = []
            toolNamesByCallID = [:]
        }

        for line in readLines(fileURL) {
            guard let object = parseJSONObject(line) else {
                parsed.skippedRecords += 1
                continue
            }
            guard let type = string(object["type"]) else { continue }

            if type == "session_meta", let payload = object["payload"] as? JSONObject {
                parsed.meta = CodexMeta(
                    id: string(payload["id"]),
                    timestamp: date(from: payload["timestamp"]),
                    cwd: string(payload["cwd"]),
                    modelProvider: string(payload["model_provider"])
                )
                continue
            }

            if type == "turn_context", let payload = object["payload"] as? JSONObject {
                flushAssistant()
                if let model = extractModel(from: payload) {
                    currentModel = model
                    parsed.model = model
                }
                continue
            }

            guard type == "response_item", let payload = object["payload"] as? JSONObject else { continue }
            guard let payloadType = string(payload["type"]) else { continue }

            if payloadType == "message" {
                let role = string(payload["role"]) ?? ""
                if role == "user" {
                    flushAssistant()
                    let text = extractCodexUserText(payload["content"])
                    guard !isBootstrapMessage(text), !text.isEmpty else { continue }
                    if parsed.title == nil { parsed.title = cleanPrompt(text) }
                    parsed.messages.append(AgentMessage(role: "user", content: text, model: nil, toolNames: []))
                } else if role == "assistant" {
                    let text = extractCodexAssistantText(payload["content"])
                    if !text.isEmpty { currentAssistantParts.append(text) }
                } else if role == "system" {
                    flushAssistant()
                    let text = extractCodexAssistantText(payload["content"])
                    appendSystemMessage(text, to: &parsed.messages)
                }
                continue
            }

            if payloadType == "reasoning" {
                let summary = extractCodexReasoningSummary(payload)
                if !summary.isEmpty { currentAssistantParts.append(summary) }
                continue
            }

            if isCodexToolCall(payloadType) {
                let toolName = string(payload["name"]) ?? (payloadType == "web_search_call" ? "web_search" : "tool")
                currentTools.insert(toolName)
                if let callID = string(payload["call_id"]) {
                    toolNamesByCallID[callID] = toolName
                }
                currentAssistantParts.append("[tool-call: \(toolName)(\(codexToolArgKeys(payload)))]")
                continue
            }

            if isCodexToolOutput(payloadType) {
                let toolName = string(payload["name"])
                    ?? string(payload["call_id"]).flatMap { toolNamesByCallID[$0] }
                    ?? "tool"
                currentAssistantParts.append("[tool-result: \(toolName)] \(previewToolOutput(payload["output"]))")
                continue
            }
        }
        flushAssistant()
        return parsed
    }
}

// MARK: - Gemini CLI

private extension AgentSessionImportService {
    func importGeminiSessions() -> AgentImportResult {
        var result = AgentImportResult()
        let geminiURL = homeDirectory.appendingPathComponent(".gemini", isDirectory: true)
        let tmpURL = geminiURL.appendingPathComponent("tmp", isDirectory: true)
        guard fileManager.fileExists(atPath: tmpURL.path) else { return result }

        let projectMap = loadGeminiProjectMap(geminiURL.appendingPathComponent("projects.json"))
        let projectDirs = directoryContents(tmpURL).filter(isDirectory)
        for projectURL in projectDirs {
            let chatsURL = projectURL.appendingPathComponent("chats", isDirectory: true)
            guard fileManager.fileExists(atPath: chatsURL.path) else { continue }
            let folder = projectMap[projectURL.lastPathComponent]
            let normalizedFolder = FolderNormalizer.normalize(folder)

            for fileURL in directoryContents(chatsURL) where fileURL.lastPathComponent.hasPrefix("session-") && fileURL.pathExtension == "json" {
                let parsed = parseGeminiSession(fileURL: fileURL)
                result.skippedRecords += parsed.skippedRecords
                guard !parsed.messages.isEmpty else {
                    result.skippedFiles += 1
                    continue
                }
                result.sessions.append(AgentSession(
                    source: .geminiCLI,
                    externalID: parsed.externalID ?? fileURL.deletingPathExtension().lastPathComponent,
                    title: parsed.title ?? title(from: parsed.messages),
                    folderPath: normalizedFolder.path,
                    folderDisplayName: normalizedFolder.displayName,
                    createdAt: parsed.createdAt ?? fileDate(fileURL, key: .creationDateKey) ?? Date(),
                    updatedAt: parsed.updatedAt ?? fileDate(fileURL, key: .contentModificationDateKey),
                    model: parsed.model,
                    toolNames: Array(parsed.toolNames).sorted(),
                    messages: parsed.messages
                ))
            }
        }

        return result
    }

    func parseGeminiSession(fileURL: URL) -> ParsedAgentSession {
        var parsed = ParsedAgentSession()
        guard
            let data = try? Data(contentsOf: fileURL),
            let root = try? JSONSerialization.jsonObject(with: data) as? JSONObject
        else {
            parsed.skippedRecords = 1
            return parsed
        }

        parsed.externalID = string(root["sessionId"])
        parsed.createdAt = date(from: root["startTime"])
        parsed.updatedAt = date(from: root["lastUpdated"])

        guard let messages = root["messages"] as? [JSONObject] else {
            parsed.skippedRecords += 1
            return parsed
        }

        for message in messages {
            let type = string(message["type"]) ?? ""
            let text = extractTextContent(message["content"]) ?? extractTextContent(message["displayContent"]) ?? ""
            switch type {
            case "user":
                appendMessage(role: "user", text: text, to: &parsed)
            case "gemini":
                var parts: [String] = []
                if let thoughts = message["thoughts"] as? [JSONObject] {
                    for thought in thoughts {
                        if let description = string(thought["description"]) ?? string(thought["subject"]) {
                            parts.append("[thinking] \(description)")
                        }
                    }
                }
                if !text.isEmpty { parts.append(text) }
                let toolNames = extractGeminiToolNames(message["toolCalls"])
                parsed.toolNames.formUnion(toolNames)
                for toolName in toolNames {
                    parts.append("[tool-call: \(toolName)]")
                }
                if let model = string(message["model"]) {
                    parsed.model = model
                }
                appendMessage(role: "assistant", text: parts.joined(separator: "\n"), model: parsed.model, tools: toolNames, to: &parsed)
            case "info", "error", "warning":
                appendMessage(role: "system", text: text.isEmpty ? "" : "[\(type)] \(text)", to: &parsed)
            default:
                continue
            }
        }

        parsed.title = title(from: parsed.messages)
        return parsed
    }

    func loadGeminiProjectMap(_ url: URL) -> [String: String] {
        guard
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? JSONObject,
            let projects = root["projects"] as? JSONObject
        else { return [:] }

        var map: [String: String] = [:]
        for (folderPath, projectName) in projects {
            if let projectName = projectName as? String {
                map[projectName] = folderPath
            }
        }
        return map
    }
}

// MARK: - Folder normalization

enum FolderNormalizer {
    static func normalize(_ raw: String?) -> (path: String?, displayName: String?) {
        guard var path = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return (nil, "Unknown project")
        }
        if path.hasPrefix("file://") {
            path = String(path.dropFirst("file://".count))
        }
        if path.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            path = home + String(path.dropFirst())
        }

        let url = URL(fileURLWithPath: path)
        let resolved: URL
        if FileManager.default.fileExists(atPath: url.path) {
            resolved = url.resolvingSymlinksInPath()
        } else {
            resolved = url.standardizedFileURL
        }

        let display = resolved.lastPathComponent.isEmpty
            ? resolved.path
            : resolved.lastPathComponent
        return (resolved.path, display)
    }

    static func entityID(for path: String) -> String {
        "folder-" + slug(path)
    }

    static func slug(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let mapped = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" {
                return Character(scalar)
            }
            return " "
        }
        return String(mapped)
            .split(separator: " ")
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

// MARK: - Parser helpers

private typealias JSONObject = [String: Any]

private struct ParsedAgentSession {
    var externalID: String?
    var title: String?
    var folderPath: String?
    var createdAt: Date?
    var updatedAt: Date?
    var model: String?
    var toolNames: Set<String> = []
    var messages: [AgentMessage] = []
    var skippedRecords: Int = 0
}

private struct ParsedCodexSession {
    var meta: CodexMeta?
    var title: String?
    var model: String?
    var toolNames: Set<String> = []
    var messages: [AgentMessage] = []
    var skippedRecords: Int = 0
}

private struct CodexMeta {
    let id: String?
    let timestamp: Date?
    let cwd: String?
    let modelProvider: String?
}

private func appendMessage(role: String, text: String?, model: String? = nil, tools: Set<String> = [], to parsed: inout ParsedAgentSession) {
    guard let cleaned = cleanedContent(text) else { return }
    if role == "user", parsed.title == nil {
        parsed.title = cleanPrompt(cleaned)
    }
    parsed.messages.append(AgentMessage(
        role: role,
        content: cleaned,
        model: model,
        toolNames: Array(tools).sorted()
    ))
}

private func appendSystemMessage(_ text: String?, to messages: inout [AgentMessage]) {
    guard let cleaned = cleanedContent(text) else { return }
    messages.append(AgentMessage(role: "system", content: cleaned, model: nil, toolNames: []))
}

private func cleanedContent(_ text: String?) -> String? {
    let cleaned = (text ?? "")
        .replacingOccurrences(of: "\u{0000}", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? nil : cleaned
}

private func title(from messages: [AgentMessage]) -> String? {
    messages.first { $0.role == "user" }
        .flatMap { cleanPrompt($0.content) }
}

private func cleanPrompt(_ text: String?) -> String? {
    guard let text else { return nil }
    let cleaned = text
        .replacingOccurrences(of: #"<system-reminder>[\s\S]*?</system-reminder>"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty, cleaned != "No prompt" else { return nil }
    return String(cleaned.prefix(120))
}

private func parseJSONObject(_ text: String) -> JSONObject? {
    guard let data = text.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? JSONObject
}

private func string(_ value: Any?) -> String? {
    if let string = value as? String, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return string
    }
    return nil
}

private func date(from value: Any?) -> Date? {
    if let number = value as? NSNumber {
        let raw = number.doubleValue
        return Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1000 : raw)
    }
    guard let raw = string(value) else { return nil }
    if let parsed = ISO8601DateFormatter().date(from: raw) {
        return parsed
    }
    let msFormatter = ISO8601DateFormatter()
    msFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = msFormatter.date(from: raw) {
        return parsed
    }
    return nil
}

private func extractTextContent(_ content: Any?) -> String? {
    if let text = string(content) { return text }
    if let object = content as? JSONObject {
        return string(object["text"])
    }
    if let parts = content as? [JSONObject] {
        let joined = parts.compactMap { part in
            string(part["text"]) ?? string(part["content"])
        }.joined(separator: "\n")
        return joined.isEmpty ? nil : joined
    }
    return nil
}

private func extractClaudeText(from message: Any?) -> String? {
    if let object = message as? JSONObject {
        return extractTextContent(object["content"])
    }
    return extractTextContent(message)
}

private func extractClaudeAssistant(from message: Any?) -> (text: String?, toolNames: Set<String>) {
    guard let object = message as? JSONObject else {
        return (extractTextContent(message), [])
    }
    if let text = string(object["content"]) {
        return (text, [])
    }
    guard let blocks = object["content"] as? [JSONObject] else {
        return (extractTextContent(object["content"]), [])
    }

    var parts: [String] = []
    var tools = Set<String>()
    for block in blocks {
        switch string(block["type"]) {
        case "text":
            if let text = string(block["text"]) { parts.append(text) }
        case "thinking":
            if let thinking = string(block["thinking"]) { parts.append("[thinking] \(thinking)") }
        case "tool_use":
            let name = string(block["name"]) ?? "tool"
            tools.insert(name)
            let keys = (block["input"] as? JSONObject)?.keys.sorted().joined(separator: ", ") ?? ""
            parts.append("[tool-call: \(name)(\(keys))]")
        case "tool_result":
            parts.append("[tool-result: tool] \(previewToolOutput(block["content"]))")
        default:
            continue
        }
    }
    return (parts.joined(separator: "\n"), tools)
}

private func extractCodexUserText(_ content: Any?) -> String {
    guard let parts = content as? [JSONObject] else { return "" }
    return parts.compactMap { part in
        guard string(part["type"]) == "input_text" else { return nil }
        return string(part["text"])
    }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

private func extractCodexAssistantText(_ content: Any?) -> String {
    guard let parts = content as? [JSONObject] else { return "" }
    return parts.compactMap { part in
        guard string(part["type"]) == "output_text" else { return nil }
        return string(part["text"])
    }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

private func extractCodexReasoningSummary(_ payload: JSONObject) -> String {
    guard let summary = payload["summary"] as? [JSONObject] else { return "" }
    return summary.compactMap { item in
        string(item["text"]).map { "[thinking] \($0)" }
    }.joined(separator: "\n")
}

private func isBootstrapMessage(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("<user_instructions>") || trimmed.hasPrefix("<environment_context>")
}

private func isCodexToolCall(_ type: String) -> Bool {
    type == "function_call" || type == "custom_tool_call" || type == "web_search_call"
}

private func isCodexToolOutput(_ type: String) -> Bool {
    type == "function_call_output" || type == "custom_tool_call_output"
}

private func codexToolArgKeys(_ payload: JSONObject) -> String {
    if let args = payload["arguments"] as? String,
       let parsed = parseJSONObject(args) {
        return parsed.keys.sorted().joined(separator: ", ")
    }
    if let args = payload["arguments"] as? JSONObject {
        return args.keys.sorted().joined(separator: ", ")
    }
    if string(payload["input"]) != nil {
        return "input"
    }
    return ""
}

private func extractModel(from object: JSONObject) -> String? {
    if let model = string(object["model"]) ?? string(object["model_name"]) {
        return model
    }
    if let info = object["info"] as? JSONObject, let model = extractModel(from: info) {
        return model
    }
    if let metadata = object["metadata"] as? JSONObject, let model = extractModel(from: metadata) {
        return model
    }
    return nil
}

private func previewToolOutput(_ value: Any?) -> String {
    let raw: String
    if let text = string(value) {
        if let parsed = parseJSONObject(text), let output = string(parsed["output"]) {
            raw = output
        } else {
            raw = text
        }
    } else if let object = value as? JSONObject,
              let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) {
        raw = json
    } else {
        raw = String(describing: value ?? "")
    }
    let oneLine = raw
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return String(oneLine.prefix(500))
}

private func extractGeminiToolNames(_ value: Any?) -> Set<String> {
    guard let calls = value as? [JSONObject] else { return [] }
    return Set(calls.compactMap { string($0["name"]) })
}

private extension AgentSessionImportService {
    func directoryContents(_ url: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    func recursiveFiles(_ root: URL, fileExtension: String) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == fileExtension {
            files.append(url)
        }
        return files.sorted { $0.path < $1.path }
    }

    func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    func readLines(_ url: URL) -> [String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return content
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func fileDate(_ url: URL, key: URLResourceKey) -> Date? {
        guard let values = try? url.resourceValues(forKeys: [key]) else { return nil }
        switch key {
        case .creationDateKey: return values.creationDate
        case .contentModificationDateKey: return values.contentModificationDate
        default: return nil
        }
    }
}
