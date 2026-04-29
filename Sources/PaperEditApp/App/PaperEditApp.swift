import AppKit
import SwiftUI

@main
struct PaperEditApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var workspaceStore = WorkspaceStore()
    @StateObject private var settingsModel = SettingsWindowModel()
    @StateObject private var updateController = UpdateController()
    @StateObject private var cloudSyncStore = CloudSyncStore(
        client: CloudKitPreferencesClient(containerIdentifier: "iCloud.com.kaelinda.PaperEdit")
    )

    var body: some Scene {
        WindowGroup("PaperEdit", id: "workspace") {
            WorkspaceRootView()
                .environmentObject(workspaceStore)
                .environmentObject(settingsModel)
                .environmentObject(cloudSyncStore)
                .frame(minWidth: 820, minHeight: 620)
                .onAppear {
                    appDelegate.fileOpenHandler = { urls in
                        workspaceStore.openExternalFiles(urls)
                    }
                }
                .task {
                    guard workspaceStore.iCloudSyncEnabled else { return }
                    await cloudSyncStore.launchSyncIfNeeded(workspaceStore: workspaceStore)
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
                .environmentObject(cloudSyncStore)
                .frame(minWidth: 520, idealWidth: 560, maxWidth: 680, minHeight: 420, idealHeight: 480)
        }
    }
}
