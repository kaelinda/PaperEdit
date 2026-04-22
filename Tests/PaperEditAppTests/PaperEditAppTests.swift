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
@Test func togglesPrimaryJSONFoldState() {
    let store = WorkspaceStore()
    store.apply(scene: .darkJSON)

    let initialText = store.activeTab?.text ?? ""
    let initialFoldState = store.activeTab?.foldMarkers.first?.isFolded
    store.togglePrimaryJSONFold()

    #expect(store.activeTab?.text != initialText)
    #expect(store.activeTab?.foldMarkers.first?.isFolded != initialFoldState)
}
