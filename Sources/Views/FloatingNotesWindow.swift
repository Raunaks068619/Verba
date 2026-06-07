import AppKit
import SwiftUI

final class FloatingNotesWindow: NSPanel {
    private static let defaultSize = NSSize(width: 540, height: 420)
    private let store: VoiceNoteStore
    private let captureOwner = "floating-notes-window"

    init(store: VoiceNoteStore = .shared) {
        self.store = store
        let rootView = FloatingNotesRootView(store: store)
        let hostingController = NSHostingController(rootView: rootView)

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        title = "\(AppBrand.name) Notes"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        contentViewController = hostingController
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        minSize = NSSize(width: 460, height: 340)
        setContentSize(Self.defaultSize)
        center()
        setFrameAutosaveName("VoiceFlowNotesCompactWindow")
        delegate = self
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func show() {
        store.beginDictationCapture(owner: captureOwner)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    deinit {
        store.endDictationCapture(owner: captureOwner)
    }
}

private struct FloatingNotesRootView: View {
    @ObservedObject var store: VoiceNoteStore
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        NotesWorkspaceView(store: store, surface: .floating, capturesDictation: false)
            .preferredColorScheme(themeManager.colorScheme)
            .ignoresSafeArea(.container, edges: .top)
    }
}

extension FloatingNotesWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        store.endDictationCapture(owner: captureOwner)
    }
}
