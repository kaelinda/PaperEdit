import AppKit
import SwiftUI

@main
struct PaperEditApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var workspaceStore = WorkspaceStore()
    @StateObject private var settingsModel = SettingsWindowModel()
    @StateObject private var updateController = UpdateController()

    var body: some Scene {
        WindowGroup("PaperEdit", id: "workspace") {
            WorkspaceRootView()
                .environmentObject(workspaceStore)
                .environmentObject(settingsModel)
                .frame(minWidth: 820, minHeight: 620)
                .onAppear {
                    appDelegate.fileOpenHandler = { urls in
                        workspaceStore.openExternalFiles(urls)
                    }
                }
        }
        .defaultSize(width: 1200, height: 780)
        .commands {
            PaperEditCommands(
                workspaceStore: workspaceStore,
                settingsModel: settingsModel,
                updateController: updateController
            )
        }

        Settings {
            SettingsRootView()
                .environmentObject(workspaceStore)
                .environmentObject(settingsModel)
                .frame(width: 560, height: 380)
        }
    }
}
