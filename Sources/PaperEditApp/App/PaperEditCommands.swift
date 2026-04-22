import AppKit
import SwiftUI

struct PaperEditCommands: Commands {
    @ObservedObject var workspaceStore: WorkspaceStore
    @ObservedObject var settingsModel: SettingsWindowModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New File") {
                workspaceStore.createUntitledTab()
            }
            .keyboardShortcut("n")

            Button("Open...") {
                workspaceStore.presentOpenPanel()
            }
            .keyboardShortcut("o")

            Button("Open Folder...") {
                workspaceStore.presentOpenFolderPanel()
            }
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                workspaceStore.saveActiveTab()
            }
            .keyboardShortcut("s")
            .disabled(workspaceStore.activeTab == nil)

            Button("Save As...") {
                workspaceStore.saveActiveTabAs()
            }
            .keyboardShortcut("S", modifiers: [.command, .shift])
            .disabled(workspaceStore.activeTab == nil)
        }

        CommandMenu("View") {
            Button("Quick Open") {
                workspaceStore.openQuickOpen()
            }
            .keyboardShortcut("p")

            Button("Command Palette") {
                workspaceStore.openCommandPalette()
            }
            .keyboardShortcut("P", modifiers: [.command, .shift])

            Divider()

            Button("Toggle Sidebar") {
                workspaceStore.toggleSidebarCollapse()
            }
            .keyboardShortcut("0", modifiers: [.command, .option])

            Button("Toggle Theme") {
                workspaceStore.toggleTheme()
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                settingsModel.selectedPane = .appearance
                workspaceStore.showSettings = true
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
