import Foundation
import Testing
@testable import PaperEditApp

@MainActor
@Test func appliesDemoScenes() {
    let store = WorkspaceStore()

    store.apply(scene: .darkJSON)
    #expect(store.themeMode == .dark)
    #expect(store.activeScene == .darkJSON)
    #expect(store.activeTab?.format == .json)
    #expect(store.openTabs.count == 4)

    store.apply(scene: .emptyState)
    #expect(store.activeTab == nil)
    #expect(store.openTabs.isEmpty)
}

@MainActor
@Test func clampsSidebarWidthAndCollapseBehavior() {
    let store = WorkspaceStore()

    store.updateSidebarWidth(400)
    #expect(store.sidebarWidth == 320)

    store.updateSidebarWidth(80)
    #expect(store.sidebarWidth == 0)

    store.toggleSidebarCollapse()
    #expect(store.sidebarWidth == 200)
}

@MainActor
@Test func openingQuickOpenRevealsCollapsedSidebar() {
    let store = WorkspaceStore()

    store.updateSidebarWidth(80)
    #expect(store.sidebarWidth == 0)

    store.openQuickOpen()
    #expect(store.showQuickOpen == true)
    #expect(store.sidebarWidth == 200)
}

@MainActor
@Test func editorFontSizeClampsAndPersists() {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = WorkspaceStore(defaults: defaults)

    for _ in 0..<32 {
        store.increaseEditorFontSize()
    }
    #expect(store.editorFontSize == 24)

    for _ in 0..<32 {
        store.decreaseEditorFontSize()
    }
    #expect(store.editorFontSize == 11)

    let restored = WorkspaceStore(defaults: defaults)
    #expect(restored.editorFontSize == 11)
}

@MainActor
@Test func interfacePreferencesPersistAndReset() {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = WorkspaceStore(defaults: defaults)
    store.setThemeMode(.dark)
    store.setSidebarMaterialStyle(.opaque)
    store.setAccentSwatch(.purple)
    store.setEditorFontSize(20)

    let restored = WorkspaceStore(defaults: defaults)
    #expect(restored.themeMode == .dark)
    #expect(restored.sidebarMaterialStyle == .opaque)
    #expect(restored.accentSwatch == .purple)
    #expect(restored.editorFontSize == 20)

    restored.resetInterfacePreferences()
    let reset = WorkspaceStore(defaults: defaults)
    #expect(reset.themeMode == WorkspaceStore.defaultThemeMode)
    #expect(reset.sidebarMaterialStyle == WorkspaceStore.defaultSidebarMaterialStyle)
    #expect(reset.accentSwatch == WorkspaceStore.defaultAccentSwatch)
    #expect(reset.editorFontSize == WorkspaceStore.defaultEditorFontSize)
}

@MainActor
@Test func opensExternalFilesAsTabs() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileURL = tempDirectory.appendingPathComponent("sample.yaml")
    try "name: paperedit".write(to: fileURL, atomically: true, encoding: .utf8)

    let store = WorkspaceStore()
    store.openExternalFiles([fileURL])

    #expect(store.activeTab?.name == "sample.yaml")
    #expect(store.activeTab?.format == .yaml)
    #expect(store.activeTab?.text.contains("paperedit") == true)
    #expect(store.viewMode == .split)
    #expect(store.previewModeAvailable == true)
}

@MainActor
@Test func openingUnavailableExternalFileDoesNotCreatePlaceholderTab() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let missingURL = tempDirectory.appendingPathComponent("missing.md")

    let store = WorkspaceStore()
    store.openExternalFiles([missingURL])

    #expect(store.openTabs.isEmpty)
    #expect(store.recentFileURLs.isEmpty)
    #expect(store.openFailureMessage == "Unable to open missing.md. Check file permissions.")
}

@MainActor
@Test func openingExternalDirectorySetsWorkspaceWithoutCreatingTab() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let store = WorkspaceStore()
    store.openExternalFiles([tempDirectory])

    #expect(store.workspaceRootURL == tempDirectory)
    #expect(store.expandedNodeIDs.contains(tempDirectory.path))
    #expect(store.openTabs.isEmpty)
}

@Test func commandLineOpenRequestResolvesRelativeAndAbsolutePaths() {
    let currentDirectoryURL = URL(fileURLWithPath: "/tmp/paper-project")

    let urls = CommandLineOpenRequest.urls(
        from: ["draft.json", "/tmp/absolute.yaml", "--ignored"],
        currentDirectoryURL: currentDirectoryURL
    )

    #expect(urls.map(\.path) == [
        "/tmp/paper-project/draft.json",
        "/tmp/absolute.yaml",
    ])
}

@MainActor
@Test func reusesExistingTabForSameExternalFile() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileURL = tempDirectory.appendingPathComponent("sample.json")
    try "{ \"paperedit\": true }".write(to: fileURL, atomically: true, encoding: .utf8)

    let store = WorkspaceStore()
    let initialCount = store.openTabs.count
    store.openExternalFiles([fileURL])
    store.openExternalFiles([fileURL])

    #expect(store.openTabs.count == initialCount + 1)
    #expect(store.activeTab?.sourceURL == fileURL)
}

@MainActor
@Test func quickOpenResultsPreferWorkspaceFilesBeforeRecentFallbacks() throws {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let workspaceConfig = tempDirectory.appendingPathComponent("project.json")
    let externalConfig = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-project.json")
    defer { try? FileManager.default.removeItem(at: externalConfig) }

    try "{}".write(to: workspaceConfig, atomically: true, encoding: .utf8)
    try "{}".write(to: externalConfig, atomically: true, encoding: .utf8)

    let store = WorkspaceStore(defaults: defaults)
    store.workspaceRootURL = tempDirectory
    store.openExternalFiles([externalConfig])
    store.openQuickOpen(prefill: "project")

    let results = store.quickOpenItems()
    #expect(results.map { $0.sourceURL.resolvingSymlinksInPath().path } == [workspaceConfig.resolvingSymlinksInPath().path, externalConfig.resolvingSymlinksInPath().path])
    #expect(results.map(\.source) == [.workspace, .recent])
}

@MainActor
@Test func quickOpenRefreshesWhenReopenedAfterWorkspaceAddsMatchingFile() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let initialConfig = tempDirectory.appendingPathComponent("project-a.json")
    try "{}".write(to: initialConfig, atomically: true, encoding: .utf8)

    let store = WorkspaceStore()
    store.workspaceRootURL = tempDirectory
    store.openQuickOpen(prefill: "project")

    let initialResults = store.quickOpenItems()
    #expect(initialResults.map { $0.sourceURL.lastPathComponent } == ["project-a.json"])

    let newConfig = tempDirectory.appendingPathComponent("project-b.json")
    try "{}".write(to: newConfig, atomically: true, encoding: .utf8)

    store.closeQuickOpen()
    store.openQuickOpen(prefill: "project")

    let refreshedResults = store.quickOpenItems()
    #expect(refreshedResults.map { $0.sourceURL.lastPathComponent }.sorted() == ["project-a.json", "project-b.json"])
}

@MainActor
@Test func quickOpenSearchMatchesFolderNamesAndPartialPaths() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let nestedDirectory = tempDirectory
        .appendingPathComponent("configs")
        .appendingPathComponent("prod")
    try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)

    let configURL = nestedDirectory.appendingPathComponent("settings.json")
    try "{}".write(to: configURL, atomically: true, encoding: .utf8)

    let store = WorkspaceStore()
    store.workspaceRootURL = tempDirectory
    store.openQuickOpen(prefill: "prod settings")

    let results = store.quickOpenItems()
    #expect(results.map { $0.sourceURL.resolvingSymlinksInPath().path } == [configURL.resolvingSymlinksInPath().path])
    #expect(results.first?.subtitle == "\(tempDirectory.lastPathComponent)/configs/prod")
}

@MainActor
@Test func quickOpenIndexesFilesBeyondPreviousFourLevelLimit() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    var deepDirectory = tempDirectory
    for component in ["one", "two", "three", "four", "five"] {
        deepDirectory = deepDirectory.appendingPathComponent(component)
    }
    try FileManager.default.createDirectory(at: deepDirectory, withIntermediateDirectories: true)

    let deepFile = deepDirectory.appendingPathComponent("deep-note.md")
    try "# deep\n".write(to: deepFile, atomically: true, encoding: .utf8)

    let store = WorkspaceStore()
    store.workspaceRootURL = tempDirectory
    store.openQuickOpen(prefill: "deep-note")

    let results = store.quickOpenItems()
    #expect(results.map { $0.sourceURL.resolvingSymlinksInPath().path } == [deepFile.resolvingSymlinksInPath().path])
}

@MainActor
@Test func quickOpenOmitsDeletedRecentFilesAndRefusesToOpenThem() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let recentURL = tempDirectory.appendingPathComponent("draft.md")
    try "# draft\n".write(to: recentURL, atomically: true, encoding: .utf8)

    let store = WorkspaceStore()
    store.recentFileURLs = [recentURL]
    store.openQuickOpen(prefill: "draft")

    try FileManager.default.removeItem(at: recentURL)

    let results = store.quickOpenItems()
    #expect(results.isEmpty)

    let staleItem = QuickOpenItem(
        title: "draft.md",
        subtitle: tempDirectory.path,
        sourceURL: recentURL,
        format: .markdown,
        source: .recent
    )
    store.openQuickOpenItem(staleItem)

    #expect(store.openTabs.isEmpty)
    #expect(store.showQuickOpen == true)
}

@MainActor
@Test func quickOpenExplainsUnreadableWorkspaceFilesWithoutOpeningPlaceholderTabs() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let unreadableURL = tempDirectory.appendingPathComponent("locked.md")
    try "# locked\n".write(to: unreadableURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o000))],
        ofItemAtPath: unreadableURL.path
    )
    defer {
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: unreadableURL.path
        )
    }

    let store = WorkspaceStore()
    store.workspaceRootURL = tempDirectory
    store.openQuickOpen(prefill: "locked")

    let results = store.quickOpenItems()
    let item = try #require(results.first { $0.sourceURL.resolvingSymlinksInPath().path == unreadableURL.resolvingSymlinksInPath().path })
    #expect(item.title == "locked.md")
    #expect(item.source == .workspace)

    store.openQuickOpenItem(item)

    #expect(store.openTabs.isEmpty)
    #expect(store.showQuickOpen == true)
    #expect(store.quickOpenErrorMessage == "Unable to open locked.md. Check file permissions.")
}

@MainActor
@Test func openingQuickOpenItemFocusesExistingTabInsteadOfDuplicatingIt() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let configURL = tempDirectory.appendingPathComponent("settings.yaml")
    try "theme: paperedit\n".write(to: configURL, atomically: true, encoding: .utf8)

    let store = WorkspaceStore()
    store.workspaceRootURL = tempDirectory
    store.openExternalFiles([configURL])
    let existingTabID = store.activeTabID

    let item = QuickOpenItem(
        title: "settings.yaml",
        subtitle: tempDirectory.path,
        sourceURL: configURL,
        format: .yaml,
        source: .workspace
    )
    store.openQuickOpenItem(item)

    #expect(store.openTabs.count == 1)
    #expect(store.activeTabID == existingTabID)
}

@MainActor
@Test func quickOpenSelectionClampsToAvailableResults() {
    let model = QuickOpenModel()

    model.selectedIndex = 1
    model.moveSelection(delta: 10, itemCount: 3)
    #expect(model.selectedIndex == 2)

    model.moveSelection(delta: -10, itemCount: 3)
    #expect(model.selectedIndex == 0)

    model.selectedIndex = 2
    model.moveSelection(delta: 1, itemCount: 0)
    #expect(model.selectedIndex == 0)
}

@MainActor
@Test func quickOpenStateIsMutuallyExclusiveWithCommandPaletteAndSceneChanges() {
    let store = WorkspaceStore()

    store.openQuickOpen(prefill: "draft")
    #expect(store.showQuickOpen == true)
    #expect(store.showCommandPalette == false)
    #expect(store.quickOpenModel.query == "draft")

    store.openCommandPalette(prefill: "theme")
    #expect(store.showQuickOpen == false)
    #expect(store.showCommandPalette == true)
    #expect(store.quickOpenModel.query.isEmpty)
    #expect(store.commandPaletteModel.query == "theme")

    store.openQuickOpen(prefill: "notes")
    #expect(store.showQuickOpen == true)
    #expect(store.showCommandPalette == false)
    #expect(store.commandPaletteModel.query.isEmpty)
    #expect(store.quickOpenModel.query == "notes")

    store.apply(scene: .darkJSON)
    #expect(store.showQuickOpen == false)
    #expect(store.showCommandPalette == false)
}

@MainActor
@Test func quickOpenWorkspaceIndexRefreshesWhenWorkspaceRootChanges() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let firstWorkspace = tempDirectory.appendingPathComponent("workspace-a")
    let secondWorkspace = tempDirectory.appendingPathComponent("workspace-b")
    try FileManager.default.createDirectory(at: firstWorkspace, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: secondWorkspace, withIntermediateDirectories: true)

    let firstConfig = firstWorkspace.appendingPathComponent("project.json")
    let secondConfig = secondWorkspace.appendingPathComponent("project.json")
    try "{}".write(to: firstConfig, atomically: true, encoding: .utf8)
    try "{}".write(to: secondConfig, atomically: true, encoding: .utf8)

    let store = WorkspaceStore()
    store.workspaceRootURL = firstWorkspace
    store.openQuickOpen()

    let firstResults = store.quickOpenItems(matching: "project")
    #expect(firstResults.map { $0.sourceURL.resolvingSymlinksInPath().path } == [firstConfig.resolvingSymlinksInPath().path])

    store.workspaceRootURL = secondWorkspace
    let secondResults = store.quickOpenItems(matching: "project")
    #expect(secondResults.map { $0.sourceURL.resolvingSymlinksInPath().path } == [secondConfig.resolvingSymlinksInPath().path])
}

@MainActor
@Test func savesDirtyExternalFiles() throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileURL = tempDirectory.appendingPathComponent("sample.toml")
    try "name = \"paperedit\"\n".write(to: fileURL, atomically: true, encoding: .utf8)

    let store = WorkspaceStore()
    store.openExternalFiles([fileURL])
    store.updateText("name = \"paperedit-pro\"\n", selection: NSRange(location: 0, length: 0))

    #expect(store.activeTab?.isDirty == true)
    #expect(store.saveActiveTab() == true)
    #expect(store.activeTab?.isDirty == false)
    #expect(try String(contentsOf: fileURL) == "name = \"paperedit-pro\"\n")
}

@MainActor
@Test func normalSaveBlocksWhenDiskChangedAfterOpen() throws {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileURL = tempDirectory.appendingPathComponent("sample.md")
    try "# original\n".write(to: fileURL, atomically: true, encoding: .utf8)

    let store = WorkspaceStore(defaults: defaults)
    store.openExternalFiles([fileURL])
    store.updateText("# local edit\n", selection: NSRange(location: 0, length: 0))

    try "# external edit with different size\n".write(to: fileURL, atomically: true, encoding: .utf8)

    #expect(store.saveActiveTab() == false)
    #expect(store.activeTab?.conflictState.isBlockingSave == true)
    #expect(try String(contentsOf: fileURL) == "# external edit with different size\n")

    #expect(store.saveActiveTabIgnoringConflict() == true)
    #expect(store.activeTab?.conflictState == FileConflictState.none)
    #expect(try String(contentsOf: fileURL) == "# local edit\n")
}

@MainActor
@Test func savedFileTabsRestoreFromSessionSnapshot() throws {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let firstURL = tempDirectory.appendingPathComponent("first.md")
    let secondURL = tempDirectory.appendingPathComponent("second.json")
    try "# first\n".write(to: firstURL, atomically: true, encoding: .utf8)
    try "{}".write(to: secondURL, atomically: true, encoding: .utf8)

    let firstStore = WorkspaceStore(defaults: defaults)
    firstStore.openExternalFiles([firstURL, secondURL])
    firstStore.setActiveTab(firstStore.openTabs[0].id)

    let restored = WorkspaceStore(defaults: defaults)
    #expect(restored.openTabs.map(\.name) == ["first.md", "second.json"])
    #expect(restored.activeTab?.name == "first.md")
    #expect(restored.openTabs.allSatisfy { $0.isDirty == false })
}

@MainActor
@Test func dirtyUntitledDraftsCanBeRecoveredFromLocalSnapshots() throws {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let draftRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: draftRoot) }
    let recoveryStore = DraftRecoveryStore(rootURL: draftRoot)

    let firstStore = WorkspaceStore(defaults: defaults, draftRecoveryStore: recoveryStore)
    firstStore.createUntitledTab()
    firstStore.updateText("unsaved note", selection: NSRange(location: 0, length: 0))

    let restored = WorkspaceStore(defaults: defaults, draftRecoveryStore: recoveryStore)
    #expect(restored.pendingDraftRecovery.count == 1)
    #expect(restored.recoveryMessage?.contains("unsaved draft") == true)

    restored.recoverPendingDrafts()
    #expect(restored.pendingDraftRecovery.isEmpty)
    #expect(restored.activeTab?.text == "unsaved note")
    #expect(restored.activeTab?.sourceURL == nil)
    #expect(restored.activeTab?.isDirty == true)
}

@MainActor
@Test func favoritesPersistAcrossStoreInstances() throws {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let configURL = tempDirectory.appendingPathComponent("settings.json")
    try #"{"theme":"paper"}"#.write(to: configURL, atomically: true, encoding: .utf8)

    let firstStore = WorkspaceStore(defaults: defaults)
    firstStore.openExternalFiles([configURL])
    firstStore.toggleFavorite(configURL)

    let secondStore = WorkspaceStore(defaults: defaults)
    #expect(secondStore.favoriteFileURLs == [configURL])
    #expect(secondStore.recentFileURLs == [configURL])
}

@MainActor
@Test func favoriteFilesAreIndependentFromOpenTabs() throws {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let configURL = tempDirectory.appendingPathComponent("app.toml")
    try "name = \"paperedit\"\n".write(to: configURL, atomically: true, encoding: .utf8)

    let store = WorkspaceStore(defaults: defaults)
    store.openExternalFiles([configURL])
    store.toggleFavorite(configURL)
    store.closeTab(store.activeTabID!)

    #expect(store.favoriteFileURLs == [configURL])
    #expect(store.favoriteFiles.map(\.sourceURL) == [configURL])
}

@MainActor
@Test func unavailableFavoritesStayPersistedAcrossRestoreAndPersist() throws {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let favoriteURL = tempDirectory.appendingPathComponent("missing-okay.json")
    try #"{"theme":"paper"}"#.write(to: favoriteURL, atomically: true, encoding: .utf8)

    let firstStore = WorkspaceStore(defaults: defaults)
    firstStore.toggleFavorite(favoriteURL)
    try FileManager.default.removeItem(at: favoriteURL)

    let secondStore = WorkspaceStore(defaults: defaults)
    #expect(secondStore.favoriteFileURLs == [favoriteURL])
    #expect(secondStore.favoriteFiles.isEmpty)

    let otherURL = tempDirectory.appendingPathComponent("other.json")
    try #"{"other":true}"#.write(to: otherURL, atomically: true, encoding: .utf8)
    secondStore.openExternalFiles([otherURL])

    #expect(defaults.stringArray(forKey: "paperedit.favorite-files") == [favoriteURL.path])
    #expect(secondStore.favoriteFileURLs == [favoriteURL])
}

@MainActor
@Test func toggleFavoriteRemovesItAndUpdatesFavoriteState() throws {
    let suiteName = "PaperEditTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Expected isolated defaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let configURL = tempDirectory.appendingPathComponent("favorite.md")
    try "# favorite\n".write(to: configURL, atomically: true, encoding: .utf8)

    let store = WorkspaceStore(defaults: defaults)
    #expect(store.isFavorite(configURL) == false)

    store.toggleFavorite(configURL)
    #expect(store.isFavorite(configURL) == true)
    #expect(store.favoriteFileURLs == [configURL])

    store.toggleFavorite(configURL)
    #expect(store.isFavorite(configURL) == false)
    #expect(store.favoriteFileURLs.isEmpty)
}

@MainActor
@Test func togglesPrimaryJSONFoldState() {
    let store = WorkspaceStore()
    store.apply(scene: .darkJSON)

    let initialText = store.activeTab?.text ?? ""
    let initialFoldState = store.activeTab?.foldMarkers.first?.isFolded
    store.togglePrimaryJSONFold()

    #expect(store.activeTab?.text != initialText)
    #expect(store.activeTab?.foldMarkers.first?.isFolded != initialFoldState)
}

@Test func buildsStructuredPreviewForJSON() {
    let document = StructuredPreviewBuilder.build(
        format: .json,
        text: #"{"name":"paperedit","features":["preview"],"enabled":true}"#
    )
    let titles = flattenTitles(document.nodes)

    #expect(document.diagnostics.isEmpty)
    #expect(titles.contains("JSON Root"))
    #expect(titles.contains("name"))
    #expect(titles.contains("features"))
}

@Test func reportsInvalidJSONDiagnostics() {
    let document = StructuredPreviewBuilder.build(
        format: .json,
        text: #"{"name":"paperedit""#
    )

    #expect(!document.diagnostics.isEmpty)
    #expect(document.nodes.isEmpty)
}

@Test func buildsStructuredPreviewForYAML() {
    let document = StructuredPreviewBuilder.build(
        format: .yaml,
        text: """
        workspace:
          name: paperedit
          formats:
            - toml
        """
    )
    let titles = flattenTitles(document.nodes)

    #expect(document.diagnostics.isEmpty)
    #expect(titles.contains("YAML Document"))
    #expect(titles.contains("workspace"))
    #expect(titles.contains("name"))
}

@Test func buildsStructuredPreviewForTOML() {
    let document = StructuredPreviewBuilder.build(
        format: .toml,
        text: """
        [workspace]
        name = "paperedit"
        preview = true
        """
    )
    let titles = flattenTitles(document.nodes)

    #expect(document.diagnostics.isEmpty)
    #expect(titles.contains("TOML Document"))
    #expect(titles.contains("workspace"))
    #expect(titles.contains("preview"))
}

@Test func buildsStructuredPreviewForXML() {
    let document = StructuredPreviewBuilder.build(
        format: .xml,
        text: #"<root><item id="1">value</item></root>"#
    )
    let titles = flattenTitles(document.nodes)

    #expect(document.diagnostics.isEmpty)
    #expect(titles.contains("root"))
    #expect(titles.contains("item"))
    #expect(titles.contains("id"))
}

@Test func reportsInvalidXMLDiagnostics() {
    let document = StructuredPreviewBuilder.build(
        format: .xml,
        text: #"<root><item></root>"#
    )

    #expect(!document.diagnostics.isEmpty)
    #expect(document.nodes.isEmpty)
}

@Test func buildsStructuredPreviewForPlist() {
    let document = StructuredPreviewBuilder.build(
        format: .plist,
        text: """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>name</key>
            <string>paperedit</string>
            <key>formats</key>
            <array>
                <string>toml</string>
                <string>plist</string>
            </array>
        </dict>
        </plist>
        """
    )
    let titles = flattenTitles(document.nodes)

    #expect(document.diagnostics.isEmpty)
    #expect(titles.contains("Property List Root"))
    #expect(titles.contains("name"))
    #expect(titles.contains("formats"))
}

@Test func reportsInvalidTOMLDiagnostics() {
    let document = StructuredPreviewBuilder.build(
        format: .toml,
        text: """
        [workspace]
        name = "paperedit"
        invalid line
        """
    )

    #expect(document.diagnostics.count == 1)
    #expect(document.diagnostics[0].contains("Line 3"))
}

@Test func detectsShellScriptFormats() {
    let scriptURL = URL(fileURLWithPath: "/tmp/deploy.sh")
    let dotfileURL = URL(fileURLWithPath: "/tmp/.zshrc")
    let shebangURL = URL(fileURLWithPath: "/tmp/bootstrap")

    #expect(EditorFileFormat(fileURL: scriptURL) == .shellScript)
    #expect(EditorFileFormat(fileURL: dotfileURL) == .shellScript)
    #expect(EditorFileFormat(fileURL: shebangURL, contents: "#!/bin/bash\necho ready\n") == .shellScript)
}

private func flattenTitles(_ nodes: [StructuredPreviewNode]) -> [String] {
    nodes.flatMap { node in
        [node.title] + flattenTitles(node.children)
    }
}

@MainActor
@Test func workspaceSyncSnapshotExportsPreferenceState() throws {
    let defaults = UserDefaults(suiteName: "paperedit.sync.snapshot.export")!
    defaults.removePersistentDomain(forName: "paperedit.sync.snapshot.export")
    let store = WorkspaceStore(defaults: defaults)
    let favoriteURL = URL(fileURLWithPath: "/tmp/paperedit-favorite.json")
    let recentURL = URL(fileURLWithPath: "/tmp/paperedit-recent.md")

    store.themeMode = .dark
    store.accentSwatch = .green
    store.sidebarMaterialStyle = .opaque
    store.sidebarSections = [.favorites, .recent]
    store.editorFontSize = 18
    store.favoriteFileURLs = [favoriteURL]
    store.recentFileURLs = [recentURL]
    store.workspaceRootURL = URL(fileURLWithPath: "/tmp")

    let updatedAt = Date(timeIntervalSince1970: 1_776_000_000)
    let snapshot = store.makeSyncSnapshot(updatedAt: updatedAt)

    #expect(snapshot.schemaVersion == 1)
    #expect(snapshot.updatedAt == updatedAt)
    #expect(snapshot.themeMode == .dark)
    #expect(snapshot.accentSwatch == .green)
    #expect(snapshot.sidebarMaterialStyle == .opaque)
    #expect(snapshot.sidebarSections == [.favorites, .recent])
    #expect(snapshot.editorFontSize == 18)
    #expect(snapshot.favoriteFilePaths == [favoriteURL.path])
    #expect(snapshot.recentFilePaths == [recentURL.path])
    #expect(snapshot.workspaceRootPath == "/tmp")
}
