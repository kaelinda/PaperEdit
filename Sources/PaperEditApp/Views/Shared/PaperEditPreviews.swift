#if DEBUG
import SwiftUI

private extension WorkspaceStore {
    static func preview(scene: DemoScene) -> WorkspaceStore {
        let store = WorkspaceStore()
        store.apply(scene: scene)
        return store
    }
}

#Preview("1. Light Markdown Split") {
    WorkspaceRootView()
        .environmentObject(WorkspaceStore.preview(scene: .lightMarkdownSplit))
        .environmentObject(SettingsWindowModel())
        .frame(width: 1200, height: 780)
}

#Preview("2. Dark JSON") {
    WorkspaceRootView()
        .environmentObject(WorkspaceStore.preview(scene: .darkJSON))
        .environmentObject(SettingsWindowModel())
        .frame(width: 1200, height: 780)
}

#Preview("3. Light YAML") {
    WorkspaceRootView()
        .environmentObject(WorkspaceStore.preview(scene: .lightYAML))
        .environmentObject(SettingsWindowModel())
        .frame(width: 1200, height: 780)
}

#Preview("4. Empty State") {
    WorkspaceRootView()
        .environmentObject(WorkspaceStore.preview(scene: .emptyState))
        .environmentObject(SettingsWindowModel())
        .frame(width: 1200, height: 780)
}

#Preview("5. Preferences") {
    SettingsRootView()
        .environmentObject(WorkspaceStore.preview(scene: .lightMarkdownSplit))
        .environmentObject(SettingsWindowModel())
        .frame(width: 560, height: 380)
}

#Preview("6. Command Palette") {
    WorkspaceRootView()
        .environmentObject(WorkspaceStore.preview(scene: .commandPalette))
        .environmentObject(SettingsWindowModel())
        .frame(width: 1200, height: 780)
}
#endif
