import SwiftUI
import UniformTypeIdentifiers

/// Editor for the magic-word registry.
///
/// **Design language**: matches Settings page — ScrollView, Theme.Space.xl
/// padding, VStack spacing 20, every group in a `themedCard()`.
///
/// **Why a tab vs. inline in Settings**: the registry can grow to 50+ entries.
/// An inline list inside the Settings tab balloons the page and pushes other
/// settings off-screen. Better as a focused surface with import/export.
struct MagicWordsSettingsView: View {
    @AppStorage(TransformerRouter.Keys.magicWordsEnabled)
    private var magicWordsEnabled: Bool = true

    @ObservedObject var store: MagicWordStore = .shared

    @State private var editing: MagicWord?
    @State private var search: String = ""
    @State private var showAddSheet = false
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDoc: MagicWordExportDocument?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                voiceActionsPanel
                customRegistryPanel
            }
            .padding(Theme.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showAddSheet) {
            MagicWordEditorSheet(
                word: nil,
                onSave: { store.add($0); showAddSheet = false },
                onCancel: { showAddSheet = false }
            )
        }
        .sheet(item: $editing) { word in
            MagicWordEditorSheet(
                word: word,
                onSave: { store.update($0); editing = nil },
                onCancel: { editing = nil }
            )
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result: result)
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDoc,
            contentType: .json,
            defaultFilename: "voiceflow-magic-words.json"
        ) { _ in }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.accent)
                    Text("Magic Words")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                }
                Text("Command phrases and custom voice shortcuts in one place.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(magicWordsEnabled ? "Enabled" : "Disabled")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Actions + snippets")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
                Toggle("", isOn: $magicWordsEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.divider, lineWidth: 1)
            )
        }
    }

    // MARK: - Voice Actions

    private var voiceActionsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        sectionIcon("sparkles")
                        Text("Built-in App Actions")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.textOnDark)
                    }
                    Text("Say these directly. VoiceFlow opens the app and, when asked, inserts your text there.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textOnDark.opacity(0.72))
                }
                Spacer()
                statusPill(magicWordsEnabled ? "Listening" : "Off",
                           color: magicWordsEnabled ? Theme.success : Theme.textTertiary)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                spacing: 12
            ) {
                actionExample(
                    title: "Open",
                    phrase: "open Codex",
                    result: "Launches Codex"
                )
                actionExample(
                    title: "Open + Insert",
                    phrase: "open Claude and type write a launch plan",
                    result: "Launches Claude, then pastes the prompt"
                )
                actionExample(
                    title: "Ask",
                    phrase: "open ChatGPT and ask improve this email",
                    result: "Opens ChatGPT with your request ready"
                )
            }

            Divider()
                .overlay(Color.white.opacity(0.12))

            HStack(alignment: .top, spacing: 14) {
                commandReference(
                    title: "Action words",
                    items: ["open", "launch", "start"]
                )
                commandReference(
                    title: "Insert words",
                    items: ["and type", "and paste", "and write", "and enter", "and ask"]
                )
                commandReference(
                    title: "Known aliases",
                    items: ["Claude / Cloud", "Codex", "ChatGPT", "Chrome", "Cursor", "VS Code", "Terminal", "Slack", "Notes"]
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .fill(Theme.surfaceDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Theme.Shadow.elevated.color,
                radius: Theme.Shadow.elevated.radius,
                x: 0, y: Theme.Shadow.elevated.y)
    }

    private func actionExample(title: String, phrase: String, result: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textOnDark.opacity(0.78))
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.accent)
            }
            Text(phrase)
                .font(.system(size: 13, weight: .semibold).monospaced())
                .foregroundColor(Theme.textOnDark)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(result)
                .font(.system(size: 11))
                .foregroundColor(Theme.textOnDark.opacity(0.60))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceDarkSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func commandReference(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textOnDark.opacity(0.64))
            FlowWrap(spacing: 6, rowSpacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textOnDark.opacity(0.86))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textOnDark)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }

    private func sectionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.accent)
            )
    }

    // MARK: - Custom Registry

    private var customRegistryPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        sectionIconLight("text.cursor")
                        Text("Custom Magic Words")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Text("Configure phrase -> expansion shortcuts. Prefix matches append anything you say after the trigger.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                countPill
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    TextField("Search phrases, expansions, tags...", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .fill(Theme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .strokeBorder(Theme.divider, lineWidth: 1)
                )

                Spacer(minLength: 8)

                secondaryButton(label: "Import", icon: "square.and.arrow.down") {
                    showImporter = true
                }
                secondaryButton(label: "Export", icon: "square.and.arrow.up") {
                    exportDoc = MagicWordExportDocument(entries: store.snapshot())
                    showExporter = true
                }
                primaryButton(label: "Add", icon: "plus") {
                    showAddSheet = true
                }
            }

            if filteredEntries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                        row(for: entry)
                            .padding(.vertical, 12)
                        if index < filteredEntries.count - 1 {
                            Divider().background(Theme.divider)
                        }
                    }
                }
            }
        }
        .themedCard()
    }

    private var countPill: some View {
        Text("\(filteredEntries.count) / \(store.entries.count)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.surfaceElevated))
            .overlay(Capsule().strokeBorder(Theme.divider, lineWidth: 1))
    }

    private func sectionIconLight(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.accent)
            )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(Theme.textSecondary)
            Text(store.entries.isEmpty ? "No Magic Words yet" : "No matches")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text(store.entries.isEmpty
                 ? "Add a phrase like \u{201C}git wip\u{201D} → \u{201C}git add -A && git commit -m\u{2026}\u{201D}."
                 : "Try a different search.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for entry: MagicWord) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\u{201C}\(entry.phrase)\u{201D}")
                        .font(.system(size: 13, weight: .semibold).monospaced())
                        .foregroundColor(Theme.textPrimary)
                    if let scope = entry.surfaceScope {
                        scopeBadge(scope)
                    }
                    if let tag = entry.tag, !tag.isEmpty {
                        tagPill(tag)
                    }
                    if !entry.enabled {
                        disabledPill
                    }
                }
                Text(entry.expansion)
                    .font(.system(size: 12).monospaced())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack(spacing: 6) {
                Toggle("", isOn: Binding(
                    get: { entry.enabled },
                    set: { newValue in
                        var updated = entry
                        updated.enabled = newValue
                        store.update(updated)
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()

                Button {
                    editing = entry
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Theme.divider, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    store.delete(id: entry.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.danger)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Theme.divider, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Pills

    private func scopeBadge(_ surface: AppSurface) -> some View {
        Text(surface.rawValue)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.accent.opacity(0.18)))
    }

    private func tagPill(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.system(size: 10))
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.divider))
    }

    private var disabledPill: some View {
        Text("disabled")
            .font(.system(size: 10))
            .foregroundColor(Theme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.divider.opacity(0.6)))
    }

    // MARK: - Buttons

    private func primaryButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.accent)
            )
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .medium))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.dividerStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var filteredEntries: [MagicWord] {
        let all = store.entries.sorted { $0.updatedAt > $1.updatedAt }
        guard !search.isEmpty else { return all }
        let q = search.lowercased()
        return all.filter {
            $0.phrase.lowercased().contains(q)
                || $0.expansion.lowercased().contains(q)
                || ($0.tag ?? "").lowercased().contains(q)
        }
    }

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let imported = try? decoder.decode([MagicWord].self, from: data) {
                store.replaceAll(imported)
            }
        case .failure(let err):
            print("Magic Words import failed: \(err)")
        }
    }
}

// MARK: - Flow layout

struct FlowWrap: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = arrangedRows(maxWidth: proposal.width, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.enumerated().reduce(CGFloat.zero) { total, item in
            total + item.element.height + (item.offset == rows.count - 1 ? 0 : rowSpacing)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = arrangedRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func arrangedRows(
        maxWidth proposedWidth: CGFloat?,
        subviews: Subviews
    ) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        guard !subviews.isEmpty else { return [] }
        let maxWidth = max(proposedWidth ?? .greatestFiniteMagnitude, 1)
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var current: [Int] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.isEmpty ? size.width : currentWidth + spacing + size.width
            if nextWidth > maxWidth, !current.isEmpty {
                rows.append((current, currentWidth, currentHeight))
                current = [index]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                current.append(index)
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !current.isEmpty {
            rows.append((current, currentWidth, currentHeight))
        }
        return rows
    }
}

// MARK: - Editor sheet

struct MagicWordEditorSheet: View {
    @State private var phrase: String
    @State private var expansion: String
    @State private var tag: String
    @State private var scope: AppSurface?
    @State private var enabled: Bool
    private let original: MagicWord?
    private let onSave: (MagicWord) -> Void
    private let onCancel: () -> Void

    init(
        word: MagicWord?,
        onSave: @escaping (MagicWord) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.original = word
        self.onSave = onSave
        self.onCancel = onCancel
        _phrase = State(initialValue: word?.phrase ?? "")
        _expansion = State(initialValue: word?.expansion ?? "")
        _tag = State(initialValue: word?.tag ?? "")
        _scope = State(initialValue: word?.surfaceScope)
        _enabled = State(initialValue: word?.enabled ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(original == nil ? "New Magic Word" : "Edit Magic Word")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(Theme.textPrimary)
                Text("Prefix-only matching. Edit distance ≤1 absorbs Whisper noise.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Phrase")
                TextField("e.g. \u{201C}git wip\u{201D}", text: $phrase)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                            .fill(Theme.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                            .strokeBorder(Theme.divider, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Expansion")
                TextEditor(text: $expansion)
                    .font(.system(size: 13).monospaced())
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                            .fill(Theme.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                            .strokeBorder(Theme.divider, lineWidth: 1)
                    )
            }

            HStack(alignment: .top, spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Tag (optional)")
                    TextField("git, k8s, sql…", text: $tag)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .fill(Theme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .strokeBorder(Theme.divider, lineWidth: 1)
                        )
                        .frame(width: 180)
                }
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Scope")
                    Picker("", selection: Binding(
                        get: { scope?.rawValue ?? "any" },
                        set: { newValue in
                            scope = newValue == "any" ? nil : AppSurface(rawValue: newValue)
                        }
                    )) {
                        Text("Any surface").tag("any")
                        ForEach(AppSurface.allKnown, id: \.self) { surface in
                            Text(surface.rawValue.capitalized).tag(surface.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Enabled")
                    Toggle("", isOn: $enabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    let word = MagicWord(
                        id: original?.id ?? UUID(),
                        phrase: phrase.trimmingCharacters(in: .whitespacesAndNewlines),
                        expansion: expansion,
                        tag: tag.isEmpty ? nil : tag,
                        surfaceScope: scope,
                        enabled: enabled,
                        updatedAt: Date()
                    )
                    onSave(word)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || expansion.isEmpty)
            }
        }
        .padding(Theme.Space.xl)
        .frame(width: 580, height: 520)
        .background(Theme.canvas)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Theme.textSecondary)
    }
}

extension AppSurface {
    /// Surfaces that make sense as a scope filter — exclude `.unknown`
    /// because filtering on "unknown" means "this should never trigger
    /// when we couldn't detect", which is a bug magnet.
    static var allKnown: [AppSurface] {
        [.ide, .terminal, .browser, .chat, .mail, .notes, .office, .database, .design]
    }
}

// MARK: - Export document

struct MagicWordExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let entries: [MagicWord]

    init(entries: [MagicWord]) {
        self.entries = entries
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.entries = (try? decoder.decode([MagicWord].self, from: data)) ?? []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        return FileWrapper(regularFileWithContents: data)
    }
}
