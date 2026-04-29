import AppKit
import Combine
import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
    private enum StorageKey {
        static let favoriteFiles = "paperedit.favorite-files"
        static let recentFiles = "paperedit.recent-files"
        static let workspaceRoot = "paperedit.workspace-root"
        static let editorFontSize = "paperedit.editor-font-size"
        static let themeMode = "paperedit.theme-mode"
        static let sidebarMaterialStyle = "paperedit.sidebar-material-style"
        static let accentSwatch = "paperedit.accent-swatch"
        static let sessionSnapshot = "paperedit.session-snapshot"
    }

    static let defaultEditorFontSize: CGFloat = 14
    static let defaultSidebarWidth: CGFloat = 240
    static let defaultThemeMode: ThemePalette = .light
    static let defaultSidebarMaterialStyle: SidebarMaterialStyle = .translucent
    static let defaultAccentSwatch: AccentSwatch = .blue

    @Published var openTabs: [EditorTab] = []
    @Published var activeTabID: EditorTab.ID?
    @Published var sidebarWidth: CGFloat = WorkspaceStore.defaultSidebarWidth
    @Published var themeMode: ThemePalette = WorkspaceStore.defaultThemeMode
    @Published var viewMode: EditorViewMode = .split
    @Published var showCommandPalette = false
    @Published var showQuickOpen = false
    @Published var quickOpenErrorMessage: String?
    @Published var quickOpenIndexMessage: String?
    @Published var openFailureMessage: String?
    @Published var showSettings = false
    @Published var activeScene: DemoScene = .lightMarkdownSplit
    @Published var status = EditorStatus.empty
    @Published var editorFontSize: CGFloat = WorkspaceStore.defaultEditorFontSize
    @Published var sidebarMaterialStyle: SidebarMaterialStyle = WorkspaceStore.defaultSidebarMaterialStyle
    @Published var accentSwatch: AccentSwatch = WorkspaceStore.defaultAccentSwatch
    @Published var sidebarSections: Set<SidebarSection> = Set(SidebarSection.allCases)
    @Published var expandedNodeIDs: Set<String> = []
    @Published var workspaceRootURL: URL? {
        didSet {
            refreshWorkspaceFileIndex()
        }
    }
    @Published var favoriteFileURLs: [URL] = []
    @Published var recentFileURLs: [URL] = []
    @Published var pendingDraftRecovery: [DraftSnapshot] = []
    @Published var recoveryMessage: String?

    let commandPaletteModel = CommandPaletteModel()
    let quickOpenModel = QuickOpenModel()
    private let defaults: UserDefaults
    private let draftRecoveryStore: DraftRecoveryStore
    private var workspaceFileIndex: [URL] = []

    private var untitledIndex = 1
    private let minEditorFontSize: CGFloat = 11
    private let maxEditorFontSize: CGFloat = 24
    private let minSidebarWidth: CGFloat = 200
    private let maxSidebarWidth: CGFloat = 320
    private let collapsedSidebarWidth: CGFloat = 0
    private let quickOpenMaxDepth = 8
    private let quickOpenMaxIndexedFiles = 2_000

    var favoriteFiles: [FileTreeNode] {
        favoriteFileURLs.compactMap { url in
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return FileTreeNode(
                id: "favorite:\(url.path)",
                name: url.lastPathComponent,
                kind: .file,
                format: EditorFileFormat(fileURL: url),
                sourceURL: url
            )
        }
    }

    var recentProjects: [FileTreeNode] {
        recentFileURLs.compactMap { url in
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return FileTreeNode(
                id: "recent:\(url.path)",
                name: url.lastPathComponent,
                kind: .file,
                format: EditorFileFormat(fileURL: url),
                sourceURL: url
            )
        }
    }

    var explorerFiles: [FileTreeNode] {
        guard let workspaceRootURL else { return [] }
        return [buildWorkspaceNode(for: workspaceRootURL)]
    }

    var activeTab: EditorTab? {
        guard let activeTabID else { return nil }
        return openTabs.first(where: { $0.id == activeTabID })
    }

    var previewModeAvailable: Bool {
        activeTab?.format.supportsStructuredPreview == true
    }

    var hasUnsavedChanges: Bool {
        openTabs.contains(where: \.isDirty)
    }

    init(defaults: UserDefaults = .standard, draftRecoveryStore: DraftRecoveryStore = DraftRecoveryStore()) {
        self.defaults = defaults
        self.draftRecoveryStore = draftRecoveryStore
        restorePersistentState()
    }

    func apply(scene: DemoScene) {
        activeScene = scene
        closeQuickOpen()
        showCommandPalette = false
        showSettings = false

        switch scene {
        case .lightMarkdownSplit:
            themeMode = .light
            viewMode = .split
            openTabs = [
                EditorSampleFactory.markdownTab(),
                EditorSampleFactory.jsonTab(),
                EditorSampleFactory.plistTab(),
            ]
            activeTabID = openTabs.first?.id
        case .darkJSON:
            themeMode = .dark
            viewMode = .edit
            openTabs = [
                EditorSampleFactory.markdownTab(),
                EditorSampleFactory.jsonTab(folded: true),
                EditorSampleFactory.plistTab(),
                EditorSampleFactory.xmlTab(),
            ]
            activeTabID = openTabs[1].id
        case .lightYAML:
            themeMode = .light
            viewMode = .edit
            openTabs = [
                EditorSampleFactory.markdownTab(),
                EditorSampleFactory.yamlTab(),
                EditorSampleFactory.tomlTab(),
            ]
            activeTabID = openTabs[1].id
        case .emptyState:
            themeMode = .light
            viewMode = .edit
            openTabs = []
            activeTabID = nil
        case .settings:
            themeMode = .light
            viewMode = .split
            openTabs = [
                EditorSampleFactory.markdownTab(),
                EditorSampleFactory.jsonTab(),
            ]
            activeTabID = openTabs.first?.id
            showSettings = true
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        case .commandPalette:
            themeMode = .dark
            viewMode = .edit
            openTabs = [
                EditorSampleFactory.jsonTab(folded: true),
                EditorSampleFactory.xmlTab(),
            ]
            activeTabID = openTabs.first?.id
            openCommandPalette(prefill: "theme")
        }

        refreshStatus()
    }

    func setActiveTab(_ tabID: EditorTab.ID) {
        activeTabID = tabID
        persistState()
        refreshStatus()
    }

    func closeTab(_ tabID: EditorTab.ID) {
        guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else { return }
        guard confirmTabCloseIfNeeded(at: index) else { return }

        if openTabs[index].sourceURL == nil {
            draftRecoveryStore.delete(id: openTabs[index].id)
        }
        openTabs.remove(at: index)
        if activeTabID == tabID {
            activeTabID = openTabs.indices.contains(index) ? openTabs[index].id : openTabs.last?.id
        }
        persistState()
        refreshStatus()
    }

    func createUntitledTab() {
        let tab = EditorSampleFactory.untitledTab(index: untitledIndex)
        untitledIndex += 1
        openTabs.append(tab)
        activeTabID = tab.id
        viewMode = tab.format.supportsStructuredPreview ? .split : .edit
        persistState()
        refreshStatus()
    }

    func openExternalFiles(_ urls: [URL]) {
        for url in urls {
            openFailureMessage = nil
            if isDirectory(url) {
                openExternalDirectory(url)
                continue
            }

            if let existing = openTabs.first(where: { isSameFileURL($0.sourceURL, url) }) {
                activeTabID = existing.id
                continue
            }

            guard FileManager.default.isReadableFile(atPath: url.path) else {
                openFailureMessage = "Unable to open \(url.lastPathComponent). Check file permissions."
                continue
            }

            let text: String
            do {
                text = try String(contentsOf: url)
            } catch {
                openFailureMessage = "Unable to open \(url.lastPathComponent). \(error.localizedDescription)"
                continue
            }

            let tab = makeExternalTab(url: url, text: text)
            openTabs.append(tab)
            activeTabID = tab.id
            noteRecentFile(url)
            if workspaceRootURL == nil {
                workspaceRootURL = url.deletingLastPathComponent()
            }
            if tab.format.supportsStructuredPreview {
                viewMode = .split
            }
        }
        persistState()
        refreshStatus()
    }

    private func openExternalDirectory(_ url: URL) {
        workspaceRootURL = url
        expandedNodeIDs.insert(url.path)
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = []
        if panel.runModal() == .OK {
            openExternalFiles(panel.urls)
        }
    }

    func presentOpenFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        workspaceRootURL = url
        expandedNodeIDs.insert(url.path)
        persistState()
    }

    func toggleSidebarCollapse() {
        sidebarWidth = sidebarWidth == collapsedSidebarWidth ? minSidebarWidth : collapsedSidebarWidth
    }

    func updateSidebarWidth(_ proposedWidth: CGFloat) {
        if proposedWidth < minSidebarWidth * 0.5 {
            sidebarWidth = collapsedSidebarWidth
            return
        }
        sidebarWidth = min(maxSidebarWidth, max(minSidebarWidth, proposedWidth))
    }

    func toggleSidebarSection(_ section: SidebarSection) {
        if sidebarSections.contains(section) {
            sidebarSections.remove(section)
        } else {
            sidebarSections.insert(section)
        }
    }

    func toggleFavorite(_ url: URL) {
        if let existingIndex = favoriteFileURLs.firstIndex(where: { isSameFileURL($0, url) }) {
            favoriteFileURLs.remove(at: existingIndex)
        } else {
            favoriteFileURLs.insert(url, at: 0)
        }
        persistState()
    }

    func isFavorite(_ url: URL) -> Bool {
        favoriteFileURLs.contains(where: { isSameFileURL($0, url) })
    }

    func toggleNodeExpansion(_ id: String) {
        if expandedNodeIDs.contains(id) {
            expandedNodeIDs.remove(id)
        } else {
            expandedNodeIDs.insert(id)
        }
    }

    func openFileTreeNode(_ node: FileTreeNode) {
        guard node.kind == .file else { return }

        if let url = node.sourceURL {
            openExternalFiles([url])
            return
        }

        let tab: EditorTab
        switch node.name {
        case "README.md":
            tab = EditorSampleFactory.markdownTab()
        case "settings.json":
            tab = EditorSampleFactory.jsonTab()
        case "docker-compose.yaml":
            tab = EditorSampleFactory.yamlTab()
        case "Cargo.toml":
            tab = EditorSampleFactory.tomlTab()
        case "layout.xml":
            tab = EditorSampleFactory.xmlTab()
        case "Info.plist":
            tab = EditorSampleFactory.plistTab()
        default:
            tab = EditorTab(name: node.name, format: node.format ?? .plainText, text: "Start typing here…")
        }

        if let existing = openTabs.first(where: { $0.name == tab.name }) {
            activeTabID = existing.id
        } else {
            openTabs.append(tab)
            activeTabID = tab.id
        }

        if let url = tab.sourceURL {
            noteRecentFile(url)
            if workspaceRootURL == nil {
                workspaceRootURL = url.deletingLastPathComponent()
            }
        }

        persistState()
        if tab.format.supportsStructuredPreview {
            viewMode = .split
        }
        refreshStatus()
    }

    func updateText(_ text: String, selection: NSRange) {
        guard let index = activeTabIndex else { return }
        let previousText = openTabs[index].text
        openTabs[index].text = text
        openTabs[index].selection = selection
        if previousText != text {
            openTabs[index].isDirty = true
            persistDraftRecoveryIfNeeded(for: openTabs[index])
        }
        refreshStatus()
    }

    func updateSelection(_ selection: NSRange) {
        guard let index = activeTabIndex else { return }
        openTabs[index].selection = selection
        refreshStatus(recalculateMetrics: false)
    }

    func setViewMode(_ mode: EditorViewMode) {
        viewMode = mode
    }

    func setThemeMode(_ mode: ThemePalette) {
        guard themeMode != mode else { return }
        themeMode = mode
        persistState()
    }

    func setSidebarMaterialStyle(_ style: SidebarMaterialStyle) {
        guard sidebarMaterialStyle != style else { return }
        sidebarMaterialStyle = style
        persistState()
    }

    func setAccentSwatch(_ swatch: AccentSwatch) {
        guard accentSwatch != swatch else { return }
        accentSwatch = swatch
        persistState()
    }

    func toggleTheme() {
        switch themeMode {
        case .light, .system:
            themeMode = .dark
        case .dark:
            themeMode = .light
        }
        persistState()
    }

    func increaseEditorFontSize() {
        setEditorFontSize(editorFontSize + 1)
    }

    func decreaseEditorFontSize() {
        setEditorFontSize(editorFontSize - 1)
    }

    func resetInterfacePreferences() {
        themeMode = WorkspaceStore.defaultThemeMode
        sidebarMaterialStyle = WorkspaceStore.defaultSidebarMaterialStyle
        accentSwatch = WorkspaceStore.defaultAccentSwatch
        editorFontSize = WorkspaceStore.defaultEditorFontSize
        sidebarWidth = WorkspaceStore.defaultSidebarWidth
        persistState()
    }

    func makeSyncSnapshot(updatedAt: Date = Date()) -> WorkspaceSyncSnapshot {
        WorkspaceSyncSnapshot(
            schemaVersion: WorkspaceSyncSnapshot.currentSchemaVersion,
            updatedAt: updatedAt,
            themeMode: themeMode,
            accentSwatch: accentSwatch,
            sidebarMaterialStyle: sidebarMaterialStyle,
            sidebarSections: SidebarSection.allCases.filter { sidebarSections.contains($0) },
            editorFontSize: Double(editorFontSize),
            favoriteFilePaths: favoriteFileURLs.map(\.path),
            recentFilePaths: recentFileURLs.map(\.path),
            workspaceRootPath: workspaceRootURL?.path
        )
    }

    func applySyncSnapshot(_ snapshot: WorkspaceSyncSnapshot) {
        guard snapshot.schemaVersion == WorkspaceSyncSnapshot.currentSchemaVersion else { return }

        themeMode = snapshot.themeMode
        accentSwatch = snapshot.accentSwatch
        sidebarMaterialStyle = snapshot.sidebarMaterialStyle
        sidebarSections = Set(snapshot.sidebarSections)
        editorFontSize = clampedEditorFontSize(CGFloat(snapshot.editorFontSize))
        favoriteFileURLs = existingFileURLs(from: snapshot.favoriteFilePaths)
        recentFileURLs = existingFileURLs(from: snapshot.recentFilePaths)

        if let workspaceRootPath = snapshot.workspaceRootPath {
            let url = URL(fileURLWithPath: workspaceRootPath)
            if isDirectory(url) {
                workspaceRootURL = url
                expandedNodeIDs.insert(url.path)
            }
        }

        persistState()
        refreshStatus()
    }

    private func existingFileURLs(from paths: [String]) -> [URL] {
        paths
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    @discardableResult
    func saveActiveTab() -> Bool {
        guard let index = activeTabIndex else { return false }
        if let existingURL = openTabs[index].sourceURL {
            guard checkSaveConflict(at: index, url: existingURL) else {
                refreshStatus()
                return false
            }
            return saveTab(at: index, to: existingURL)
        }
        return saveActiveTabAs()
    }

    @discardableResult
    func saveActiveTabIgnoringConflict() -> Bool {
        guard let index = activeTabIndex else { return false }
        if let existingURL = openTabs[index].sourceURL {
            return saveTab(at: index, to: existingURL)
        }
        return saveActiveTabAs()
    }

    func keepLocalVersionForActiveTab() {
        guard let index = activeTabIndex else { return }
        openTabs[index].conflictState = .none
        refreshStatus()
    }

    func reloadActiveTabFromDisk() {
        guard
            let index = activeTabIndex,
            let url = openTabs[index].sourceURL,
            FileManager.default.isReadableFile(atPath: url.path),
            let text = try? String(contentsOf: url)
        else { return }

        let format = EditorFileFormat(fileURL: url, contents: text)
        openTabs[index].text = text
        openTabs[index].format = format
        openTabs[index].name = url.lastPathComponent
        openTabs[index].isDirty = false
        openTabs[index].fileBaseline = FileBaseline.current(for: url)
        openTabs[index].conflictState = .none
        persistState()
        refreshStatus()
    }

    func recoverPendingDrafts() {
        for snapshot in pendingDraftRecovery {
            let tab = EditorTab(
                id: snapshot.id,
                name: snapshot.name,
                format: snapshot.format,
                text: snapshot.text,
                isDirty: true,
                selection: NSRange(location: 0, length: 0)
            )
            if !openTabs.contains(where: { $0.id == tab.id }) {
                openTabs.append(tab)
            }
            draftRecoveryStore.delete(id: snapshot.id)
        }
        activeTabID = openTabs.last?.id ?? activeTabID
        pendingDraftRecovery = []
        recoveryMessage = nil
        persistState()
        refreshStatus()
    }

    func discardPendingDrafts() {
        for snapshot in pendingDraftRecovery {
            draftRecoveryStore.delete(id: snapshot.id)
        }
        pendingDraftRecovery = []
        recoveryMessage = nil
    }

    @discardableResult
    func saveActiveTabAs() -> Bool {
        guard let index = activeTabIndex else { return false }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = suggestedSaveFilename(for: openTabs[index])
        if let contentType = openTabs[index].format.contentType {
            panel.allowedContentTypes = [contentType]
        }

        if panel.runModal() == .OK, let url = panel.url {
            return saveTab(at: index, to: url)
        }

        return false
    }

    func openCommandPalette(prefill: String = "") {
        closeQuickOpen()
        showCommandPalette = true
        commandPaletteModel.reset()
        commandPaletteModel.query = prefill
    }

    func closeCommandPalette() {
        showCommandPalette = false
        commandPaletteModel.reset()
    }

    func openQuickOpen(prefill: String = "") {
        closeCommandPalette()
        if sidebarWidth < minSidebarWidth {
            sidebarWidth = minSidebarWidth
        }
        showQuickOpen = true
        quickOpenErrorMessage = nil
        quickOpenIndexMessage = nil
        quickOpenModel.reset()
        quickOpenModel.query = prefill
        refreshWorkspaceFileIndex()
    }

    func closeQuickOpen() {
        showQuickOpen = false
        quickOpenErrorMessage = nil
        quickOpenIndexMessage = nil
        quickOpenModel.reset()
    }

    func quickOpenItems(matching rawQuery: String? = nil) -> [QuickOpenItem] {
        let tokens = quickOpenSearchTokens(from: rawQuery ?? quickOpenModel.query)
        var seenPaths = Set<String>()

        let workspaceMatches = workspaceFileIndex
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .filter { quickOpenURL($0, matches: tokens) }
            .compactMap { url -> QuickOpenItem? in
                guard seenPaths.insert(normalizedFilePath(for: url)).inserted else { return nil }
                return QuickOpenItem(
                    title: url.lastPathComponent,
                    subtitle: quickOpenSubtitle(for: url),
                    sourceURL: url,
                    format: EditorFileFormat(fileURL: url),
                    source: .workspace
                )
            }

        let recentMatches = recentFileURLs
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .filter { quickOpenURL($0, matches: tokens) }
            .compactMap { url -> QuickOpenItem? in
                guard seenPaths.insert(normalizedFilePath(for: url)).inserted else { return nil }
                return QuickOpenItem(
                    title: url.lastPathComponent,
                    subtitle: quickOpenSubtitle(for: url),
                    sourceURL: url,
                    format: EditorFileFormat(fileURL: url),
                    source: .recent
                )
            }

        return workspaceMatches + recentMatches
    }

    private func quickOpenSearchTokens(from query: String) -> [String] {
        query
            .lowercased()
            .split { character in
                character.isWhitespace || character == "/" || character == "\\"
            }
            .map(String.init)
    }

    private func quickOpenURL(_ url: URL, matches tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }
        let haystack = [
            url.lastPathComponent,
            url.deletingLastPathComponent().path,
            quickOpenSubtitle(for: url),
        ]
        .joined(separator: " ")
        .lowercased()

        return tokens.allSatisfy { haystack.contains($0) }
    }

    private func quickOpenSubtitle(for url: URL) -> String {
        guard let workspaceRootURL else {
            return url.deletingLastPathComponent().path
        }

        let rootPath = normalizedFilePath(for: workspaceRootURL)
        let filePath = normalizedFilePath(for: url)
        guard filePath == rootPath || filePath.hasPrefix(rootPath + "/") else {
            return url.deletingLastPathComponent().path
        }

        let relativePath = String(filePath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let relativeDirectory = (relativePath as NSString).deletingLastPathComponent
        return relativeDirectory.isEmpty ? workspaceRootURL.lastPathComponent : "\(workspaceRootURL.lastPathComponent)/\(relativeDirectory)"
    }

    func openQuickOpenItem(_ item: QuickOpenItem) {
        guard canOpenQuickOpenItem(item) else {
            quickOpenErrorMessage = "Unable to open \(item.title). Check file permissions."
            return
        }
        quickOpenErrorMessage = nil
        openExternalFiles([item.sourceURL])
        closeQuickOpen()
    }

    func filteredCommands() -> [CommandItem] {
        let items = commandItems()
        guard !commandPaletteModel.query.isEmpty else { return items }

        let needle = commandPaletteModel.query.lowercased()
        return items.filter { item in
            item.title.lowercased().contains(needle)
                || item.subtitle.lowercased().contains(needle)
                || item.category.lowercased().contains(needle)
                || item.keywords.contains(where: { $0.lowercased().contains(needle) })
        }
    }

    func executeCommand(_ item: CommandItem, settingsModel: SettingsWindowModel) {
        switch item.action {
        case .openSettings(let pane):
            settingsModel.selectedPane = pane
            showSettings = true
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        case .toggleTheme:
            toggleTheme()
        case .toggleSidebar:
            toggleSidebarCollapse()
        case .newFile:
            createUntitledTab()
        case .openFile:
            presentOpenPanel()
        case .openFolder:
            presentOpenFolderPanel()
        case .saveFile:
            saveActiveTab()
        case .saveFileAs:
            saveActiveTabAs()
        case .activateScene(let scene):
            apply(scene: scene)
        case .setPreviewMode(let mode):
            viewMode = mode
        }
        closeCommandPalette()
    }

    func togglePrimaryJSONFold() {
        guard
            let index = activeTabIndex,
            openTabs[index].format == .json
        else { return }

        let isFolded = openTabs[index].foldMarkers.first?.isFolded ?? false
        openTabs[index] = EditorSampleFactory.jsonTab(folded: !isFolded)
        activeTabID = openTabs[index].id
        refreshStatus()
    }

    private var activeTabIndex: Int? {
        guard let activeTabID else { return nil }
        return openTabs.firstIndex(where: { $0.id == activeTabID })
    }

    private func suggestedSaveFilename(for tab: EditorTab) -> String {
        guard let preferredExtension = tab.format.preferredFilenameExtension else {
            return tab.name
        }
        if tab.name.lowercased().hasSuffix(".\(preferredExtension)") {
            return tab.name
        }
        return "\(tab.name).\(preferredExtension)"
    }

    private func canOpenQuickOpenItem(_ item: QuickOpenItem) -> Bool {
        if openTabs.contains(where: { isSameFileURL($0.sourceURL, item.sourceURL) }) {
            return true
        }

        guard FileManager.default.isReadableFile(atPath: item.sourceURL.path) else {
            return false
        }

        return (try? String(contentsOf: item.sourceURL)) != nil
    }

    private func makeExternalTab(url: URL, text: String) -> EditorTab {
        let format = EditorFileFormat(fileURL: url, contents: text)
        return EditorTab(
            name: url.lastPathComponent,
            format: format,
            text: text,
            sourceURL: url,
            isDirty: false,
            selection: .init(location: 0, length: 0),
            foldMarkers: format == .json ? [EditorFoldMarker(line: 1, level: 0, isFolded: false)] : [],
            showsFolding: format == .json,
            fileBaseline: FileBaseline.current(for: url)
        )
    }

    private func checkSaveConflict(at index: Int, url: URL) -> Bool {
        guard let baseline = openTabs[index].fileBaseline else {
            if FileBaseline.current(for: url) == nil {
                openTabs[index].conflictState = .metadataUnavailable(path: url.path)
                return false
            }
            return true
        }

        guard let current = FileBaseline.current(for: url) else {
            openTabs[index].conflictState = .metadataUnavailable(path: url.path)
            return false
        }

        guard current == baseline else {
            openTabs[index].conflictState = .externallyModified(path: url.path)
            return false
        }

        openTabs[index].conflictState = .none
        return true
    }

    @discardableResult
    private func saveTab(at index: Int, to url: URL) -> Bool {
        do {
            try openTabs[index].text.write(to: url, atomically: true, encoding: .utf8)
            openTabs[index].sourceURL = url
            openTabs[index].name = url.lastPathComponent
            openTabs[index].format = EditorFileFormat(fileURL: url, contents: openTabs[index].text)
            openTabs[index].isDirty = false
            openTabs[index].fileBaseline = FileBaseline.current(for: url)
            openTabs[index].conflictState = .none
            draftRecoveryStore.delete(id: openTabs[index].id)
            noteRecentFile(url)
            if workspaceRootURL == nil {
                workspaceRootURL = url.deletingLastPathComponent()
            }
            persistState()
            refreshStatus()
            return true
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Couldn’t Save \(openTabs[index].name)"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }

    private func confirmTabCloseIfNeeded(at index: Int) -> Bool {
        guard openTabs[index].isDirty else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save changes to \(openTabs[index].name)?"
        alert.informativeText = "Your edits will be lost if you close this tab without saving."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don’t Save")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let existingURL = openTabs[index].sourceURL {
                guard checkSaveConflict(at: index, url: existingURL) else { return false }
                return saveTab(at: index, to: existingURL)
            }
            guard let saveURL = presentSaveURL(for: openTabs[index]) else { return false }
            return saveTab(at: index, to: saveURL)
        case .alertSecondButtonReturn:
            return false
        default:
            return true
        }
    }

    private func presentSaveURL(for tab: EditorTab) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = suggestedSaveFilename(for: tab)
        if let contentType = tab.format.contentType {
            panel.allowedContentTypes = [contentType]
        }

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private func noteRecentFile(_ url: URL) {
        recentFileURLs.removeAll { isSameFileURL($0, url) }
        recentFileURLs.insert(url, at: 0)
        recentFileURLs = Array(recentFileURLs.prefix(12))
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    private func persistDraftRecoveryIfNeeded(for tab: EditorTab) {
        guard tab.sourceURL == nil, tab.isDirty, !tab.text.isEmpty else {
            if tab.sourceURL == nil {
                draftRecoveryStore.delete(id: tab.id)
            }
            return
        }

        let snapshot = DraftSnapshot(
            id: tab.id,
            name: tab.name,
            text: tab.text,
            format: tab.format,
            updatedAt: Date()
        )
        try? draftRecoveryStore.write(snapshot)
    }

    private func isSameFileURL(_ lhs: URL?, _ rhs: URL) -> Bool {
        guard let lhs else { return false }
        return normalizedFilePath(for: lhs) == normalizedFilePath(for: rhs)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func normalizedFilePath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func persistState() {
        defaults.set(favoriteFileURLs.map(\.path), forKey: StorageKey.favoriteFiles)
        defaults.set(recentFileURLs.map(\.path), forKey: StorageKey.recentFiles)
        defaults.set(workspaceRootURL?.path, forKey: StorageKey.workspaceRoot)
        defaults.set(Double(editorFontSize), forKey: StorageKey.editorFontSize)
        defaults.set(themeMode.rawValue, forKey: StorageKey.themeMode)
        defaults.set(sidebarMaterialStyle.rawValue, forKey: StorageKey.sidebarMaterialStyle)
        defaults.set(accentSwatch.rawValue, forKey: StorageKey.accentSwatch)
        persistSessionSnapshot()
    }

    private func restorePersistentState() {
        favoriteFileURLs = (defaults.stringArray(forKey: StorageKey.favoriteFiles) ?? [])
            .map(URL.init(fileURLWithPath:))

        recentFileURLs = (defaults.stringArray(forKey: StorageKey.recentFiles) ?? [])
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        if let workspaceRootPath = defaults.string(forKey: StorageKey.workspaceRoot) {
            let url = URL(fileURLWithPath: workspaceRootPath)
            if FileManager.default.fileExists(atPath: url.path) {
                workspaceRootURL = url
                expandedNodeIDs.insert(url.path)
            }
        }

        if let storedEditorFontSize = defaults.object(forKey: StorageKey.editorFontSize) as? Double {
            editorFontSize = clampedEditorFontSize(CGFloat(storedEditorFontSize))
        }
        if let storedThemeMode = defaults.string(forKey: StorageKey.themeMode),
           let restoredThemeMode = ThemePalette(rawValue: storedThemeMode) {
            themeMode = restoredThemeMode
        }
        if let storedSidebarMaterialStyle = defaults.string(forKey: StorageKey.sidebarMaterialStyle),
           let restoredSidebarMaterialStyle = SidebarMaterialStyle(rawValue: storedSidebarMaterialStyle) {
            sidebarMaterialStyle = restoredSidebarMaterialStyle
        }
        if let storedAccentSwatch = defaults.string(forKey: StorageKey.accentSwatch),
           let restoredAccentSwatch = AccentSwatch(rawValue: storedAccentSwatch) {
            accentSwatch = restoredAccentSwatch
        }

        activeScene = .emptyState
        restoreSessionSnapshot()
        pendingDraftRecovery = draftRecoveryStore.readSnapshots()
        if !pendingDraftRecovery.isEmpty {
            recoveryMessage = "\(pendingDraftRecovery.count) unsaved draft\(pendingDraftRecovery.count == 1 ? "" : "s") can be recovered. Drafts are stored locally on this Mac."
        }
        refreshWorkspaceFileIndex()
        refreshStatus()
    }

    private func persistSessionSnapshot() {
        let tabs = openTabs.compactMap { tab -> SessionTabSnapshot? in
            guard let url = tab.sourceURL else { return nil }
            return SessionTabSnapshot(
                path: url.path,
                selectionLocation: tab.selection.location,
                selectionLength: tab.selection.length
            )
        }
        guard !tabs.isEmpty else {
            defaults.removeObject(forKey: StorageKey.sessionSnapshot)
            return
        }

        let activePath = activeTab?.sourceURL?.path
        let snapshot = SessionSnapshot(tabs: tabs, activePath: activePath)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: StorageKey.sessionSnapshot)
        }
    }

    private func restoreSessionSnapshot() {
        openTabs = []
        activeTabID = nil

        guard
            let data = defaults.data(forKey: StorageKey.sessionSnapshot),
            let snapshot = try? JSONDecoder().decode(SessionSnapshot.self, from: data),
            snapshot.schemaVersion == 1
        else {
            return
        }

        for tabSnapshot in snapshot.tabs {
            let url = URL(fileURLWithPath: tabSnapshot.path)
            guard
                url.isFileURL,
                !isDirectory(url),
                FileManager.default.isReadableFile(atPath: url.path),
                let text = try? String(contentsOf: url)
            else {
                continue
            }

            var tab = makeExternalTab(url: url, text: text)
            let nsText = text as NSString
            let location = min(max(0, tabSnapshot.selectionLocation), nsText.length)
            let length = min(max(0, tabSnapshot.selectionLength), nsText.length - location)
            tab.selection = NSRange(location: location, length: length)
            openTabs.append(tab)
        }

        if let activePath = snapshot.activePath,
           let active = openTabs.first(where: { $0.sourceURL?.path == activePath }) {
            activeTabID = active.id
        } else {
            activeTabID = openTabs.first?.id
        }

        if openTabs.contains(where: { $0.format.supportsStructuredPreview }) {
            viewMode = .split
        }
    }

    private func buildWorkspaceNode(for url: URL) -> FileTreeNode {
        FileTreeNode(
            name: url.lastPathComponent,
            kind: .folder,
            sourceURL: url,
            children: buildChildren(for: url, depth: 0)
        )
    }

    private func collectWorkspaceFileURLs() -> [URL] {
        guard let workspaceRootURL else { return [] }
        return collectWorkspaceFileURLs(in: workspaceRootURL, depth: 0)
    }

    private func refreshWorkspaceFileIndex() {
        guard workspaceRootURL != nil else {
            workspaceFileIndex = []
            quickOpenIndexMessage = nil
            return
        }

        workspaceFileIndex = collectWorkspaceFileURLs()
    }

    private func collectWorkspaceFileURLs(in directoryURL: URL, depth: Int) -> [URL] {
        var results: [URL] = []
        var skippedDirectories = 0
        collectWorkspaceFileURLs(
            in: directoryURL,
            depth: depth,
            results: &results,
            skippedDirectories: &skippedDirectories
        )
        if results.count >= quickOpenMaxIndexedFiles {
            quickOpenIndexMessage = "Quick Open is showing the first \(quickOpenMaxIndexedFiles) files. Narrow your search or open a deeper folder."
        } else if skippedDirectories > 0 {
            quickOpenIndexMessage = "Quick Open skips heavy folders and searches up to \(quickOpenMaxDepth) levels deep."
        } else {
            quickOpenIndexMessage = nil
        }
        return results
    }

    private func collectWorkspaceFileURLs(
        in directoryURL: URL,
        depth: Int,
        results: inout [URL],
        skippedDirectories: inout Int
    ) {
        guard results.count < quickOpenMaxIndexedFiles else { return }
        guard depth < quickOpenMaxDepth else {
            skippedDirectories += 1
            return
        }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isHiddenKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let sortedURLs = urls.sorted { lhs, rhs in
            lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
        }
        for url in sortedURLs {
            guard results.count < quickOpenMaxIndexedFiles else { return }
            guard let values = try? url.resourceValues(forKeys: keys), values.isHidden != true else { continue }
            if values.isDirectory == true {
                guard ![".git", ".build", "node_modules", ".swiftpm", "DerivedData"].contains(url.lastPathComponent) else {
                    skippedDirectories += 1
                    continue
                }
                collectWorkspaceFileURLs(in: url, depth: depth + 1, results: &results, skippedDirectories: &skippedDirectories)
            } else if values.isRegularFile == true {
                results.append(url)
            }
        }
    }

    private func buildChildren(for directoryURL: URL, depth: Int) -> [FileTreeNode] {
        guard depth < 4 else { return [] }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isHiddenKey, .isPackageKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .compactMap { url -> FileTreeNode? in
                guard let values = try? url.resourceValues(forKeys: keys), values.isHidden != true else { return nil }
                if values.isDirectory == true {
                    guard ![".git", ".build", "node_modules", ".swiftpm", "DerivedData"].contains(url.lastPathComponent) else {
                        return nil
                    }
                    return FileTreeNode(
                        name: url.lastPathComponent,
                        kind: .folder,
                        sourceURL: url,
                        children: buildChildren(for: url, depth: depth + 1)
                    )
                }

                guard values.isRegularFile == true else { return nil }
                return FileTreeNode(
                    name: url.lastPathComponent,
                    kind: .file,
                    format: EditorFileFormat(fileURL: url),
                    sourceURL: url
                )
            }
            .sorted { lhs, rhs in
                if lhs.kind == .folder, rhs.kind != .folder { return true }
                if lhs.kind != .folder, rhs.kind == .folder { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func refreshStatus(recalculateMetrics: Bool = true) {
        guard let tab = activeTab else {
            status = .empty
            return
        }

        let nsText = tab.text as NSString
        let selectionLocation = min(tab.selection.location, nsText.length)
        let prefix = nsText.substring(to: selectionLocation)
        let lines = prefix.components(separatedBy: "\n")
        let line = max(1, lines.count)
        let column = (lines.last?.count ?? 0) + 1
        let metricValue: String
        if recalculateMetrics {
            metricValue = switch tab.format {
            case .markdown:
                "\(tab.text.split(whereSeparator: \.isWhitespace).count) words"
            default:
                "\(tab.text.components(separatedBy: "\n").count) lines"
            }
        } else {
            metricValue = status.metrics
        }

        status = EditorStatus(
            format: tab.format.displayName,
            encoding: "UTF-8",
            line: line,
            column: column,
            metrics: metricValue
        )
    }

    func setEditorFontSize(_ fontSize: CGFloat) {
        let clamped = clampedEditorFontSize(fontSize)
        guard clamped != editorFontSize else { return }
        editorFontSize = clamped
        persistState()
    }

    private func clampedEditorFontSize(_ fontSize: CGFloat) -> CGFloat {
        min(max(fontSize, minEditorFontSize), maxEditorFontSize)
    }

    private func commandItems() -> [CommandItem] {
        [
            CommandItem(
                category: "Preferences",
                title: "Preferences: Open Theme Settings",
                subtitle: "Open the Appearance pane",
                shortcut: "⌘,",
                symbolName: "paintpalette",
                keywords: ["theme", "appearance", "color"],
                action: .openSettings(.appearance)
            ),
            CommandItem(
                category: "View",
                title: "View: Toggle Color Theme",
                subtitle: "Switch between PaperEdit Light and Dark",
                shortcut: "⌥⌘T",
                symbolName: "circle.lefthalf.filled",
                keywords: ["theme", "dark", "light"],
                action: .toggleTheme
            ),
            CommandItem(
                category: "View",
                title: "View: Toggle Sidebar",
                subtitle: "Collapse or reveal the file tree",
                shortcut: "⌥⌘0",
                symbolName: "sidebar.left",
                keywords: ["sidebar", "explorer"],
                action: .toggleSidebar
            ),
            CommandItem(
                category: "File",
                title: "File: New File",
                subtitle: "Create a new markdown draft tab",
                shortcut: "⌘N",
                symbolName: "doc.badge.plus",
                keywords: ["new", "file"],
                action: .newFile
            ),
            CommandItem(
                category: "File",
                title: "File: Open…",
                subtitle: "Import one or more local files",
                shortcut: "⌘O",
                symbolName: "folder",
                keywords: ["open", "import"],
                action: .openFile
            ),
            CommandItem(
                category: "File",
                title: "File: Open Folder…",
                subtitle: "Browse a workspace in the sidebar",
                symbolName: "folder.badge.plus",
                keywords: ["folder", "workspace", "browse"],
                action: .openFolder
            ),
            CommandItem(
                category: "File",
                title: "File: Save",
                subtitle: "Write the current tab to disk",
                shortcut: "⌘S",
                symbolName: "square.and.arrow.down",
                keywords: ["save", "write", "disk"],
                action: .saveFile
            ),
            CommandItem(
                category: "File",
                title: "File: Save As…",
                subtitle: "Choose a new location for the current tab",
                shortcut: "⇧⌘S",
                symbolName: "square.and.arrow.down.on.square",
                keywords: ["save as", "export", "duplicate"],
                action: .saveFileAs
            ),
            CommandItem(
                category: "Preview",
                title: "Preview: Split View",
                subtitle: "Edit beside Markdown or structured data preview",
                symbolName: "rectangle.split.2x1",
                keywords: ["markdown", "json", "yaml", "toml", "xml", "plist", "split", "preview"],
                action: .setPreviewMode(.split)
            ),
            CommandItem(
                category: "Preview",
                title: "Preview: Rendered View",
                subtitle: "Show only the rendered or structured preview",
                symbolName: "eye",
                keywords: ["markdown", "json", "yaml", "toml", "xml", "plist", "structure", "preview"],
                action: .setPreviewMode(.wysiwyg)
            ),
        ]
    }

    private static func collectNodeIDs(from node: FileTreeNode) -> [String] {
        [node.id] + node.children.flatMap(collectNodeIDs(from:))
    }
}
