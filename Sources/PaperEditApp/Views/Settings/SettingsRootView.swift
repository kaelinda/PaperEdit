import AppKit
import SwiftUI

struct SettingsRootView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var settingsModel: SettingsWindowModel
    @EnvironmentObject private var cloudSyncStore: CloudSyncStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSyncedPulse = false

    private var theme: PaperTheme {
        PaperTheme.resolve(from: workspaceStore.themeMode, colorScheme: colorScheme, accentSwatch: workspaceStore.accentSwatch)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Text("Preferences")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                HStack(spacing: 0) {
                    ForEach(PreferencePane.allCases) { pane in
                        settingsTabButton(pane)

                        if pane != PreferencePane.allCases.last {
                            Rectangle()
                                .fill(theme.border)
                                .frame(width: 1, height: 20)
                        }
                    }
                }
                .padding(2)
                .background(theme.windowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    settingsPaneContent
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }

            HStack {
                Button("Restore Defaults") {
                    workspaceStore.resetInterfacePreferences()
                }
                    .buttonStyle(.bordered)
                    .help("Restore appearance and editor preferences")

                Spacer()

                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(theme.windowBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(theme.border)
                    .frame(height: 1)
            }
        }
        .background(theme.editorBackground)
        .preferredColorScheme(preferredColorScheme)
    }

    private func settingsTabButton(_ pane: PreferencePane) -> some View {
        Button {
            settingsModel.selectedPane = pane
        } label: {
            Text(pane.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(settingsModel.selectedPane == pane ? theme.accent : theme.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(settingsModel.selectedPane == pane ? theme.elevatedBackground : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var settingsPaneContent: some View {
        switch settingsModel.selectedPane {
        case .general:
            settingsCard("Workspace") {
                labeledValueRow("Startup", value: "Restore saved-file tabs")
                labeledValueRow("Default open behavior", value: "Last workspace")
            }
        case .editor:
            settingsCard("Text") {
                fontSizeStepperRow
                labeledValueRow("Line height", value: "Automatic")
            }

            settingsCard("Code Editing") {
                labeledValueRow("Line numbers", value: "Always on")
                labeledValueRow("Current line", value: "Highlighted")
                labeledValueRow("Word wrap", value: "Off")
            }
        case .appearance:
            settingsCard("Theme") {
                labeledPickerRow("Color Theme", selection: themeModeBinding, values: ThemePalette.allCases)
                accentRow
                labeledPickerRow("Sidebar Material", selection: sidebarMaterialStyleBinding, values: SidebarMaterialStyle.allCases)
            }
        case .sync:
            settingsCard("iCloud Sync") {
                syncToggleRow
                Group {
                    syncScopeRow
                    syncStatusRow
                    syncPrivacyNoteRow
                    syncPathNoteRow
                }
                .opacity(workspaceStore.iCloudSyncEnabled ? 1.0 : 0.6)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: workspaceStore.iCloudSyncEnabled)
            }
            .onChange(of: cloudSyncStore.status) { _, newValue in
                guard case .synced = newValue, !showSyncedPulse else { return }
                showSyncedPulse = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showSyncedPulse = false
                }
            }
        case .shortcuts:
            settingsCard("Core Shortcuts") {
                shortcutRow("New File", "⌘N")
                shortcutRow("Open File", "⌘O")
                shortcutRow("Command Palette", "⌘⇧P")
                shortcutRow("Preferences", "⌘,")
            }
        }
    }

    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                content()
            }
            .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
    }

    private func labeledValueRow(_ title: String, value: String) -> some View {
        settingsRow {
            Text(title)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(value)
                .foregroundStyle(theme.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }

    private var fontSizeStepperRow: some View {
        settingsRow {
            Text("Font size")
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
            Spacer()
            Stepper(
                value: editorFontSizeBinding,
                in: 11.0...24.0,
                step: 1
            ) {
                Text("\(Int(workspaceStore.editorFontSize)) pt")
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
            }
            .accessibilityLabel("Editor Font Size")
            .accessibilityValue("\(Int(workspaceStore.editorFontSize)) points")
        }
    }

    private var accentRow: some View {
        settingsRow {
            Text("Accent Color")
                .foregroundStyle(theme.textPrimary)
            Spacer()
            HStack(spacing: 10) {
                ForEach(AccentSwatch.allCases) { swatch in
                    Button {
                        workspaceStore.setAccentSwatch(swatch)
                    } label: {
                        Circle()
                            .fill(swatch.displayColor)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(workspaceStore.accentSwatch == swatch ? theme.textPrimary : .clear, lineWidth: 2)
                                    .padding(-4)
                            )
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(swatch.displayName) Accent")
                    .accessibilityValue(workspaceStore.accentSwatch == swatch ? "Selected" : "")
                    .help("\(swatch.displayName) accent")
                }
            }
        }
    }

    private func labeledPickerRow<T: CaseIterable & Hashable>(_ title: String, selection: Binding<T>, values: T.AllCases) -> some View where T.AllCases: RandomAccessCollection, T: CustomStringConvertible {
        settingsRow {
            Text(title)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
            Spacer()
            Picker("", selection: selection) {
                ForEach(Array(values), id: \.self) { value in
                    Text(value.description).tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 180, idealWidth: 210, maxWidth: 240)
            .accessibilityLabel(title)
        }
    }

    private func shortcutRow(_ title: String, _ shortcut: String) -> some View {
        settingsRow {
            Text(title)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.windowBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
                .foregroundStyle(theme.textPrimary)
        }
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                content()
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)

            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch workspaceStore.themeMode {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    private var editorFontSizeBinding: Binding<Double> {
        Binding(
            get: { Double(workspaceStore.editorFontSize) },
            set: { workspaceStore.setEditorFontSize(CGFloat($0)) }
        )
    }

    private var themeModeBinding: Binding<ThemePalette> {
        Binding(
            get: { workspaceStore.themeMode },
            set: { workspaceStore.setThemeMode($0) }
        )
    }

    private var sidebarMaterialStyleBinding: Binding<SidebarMaterialStyle> {
        Binding(
            get: { workspaceStore.sidebarMaterialStyle },
            set: { workspaceStore.setSidebarMaterialStyle($0) }
        )
    }

    private var syncToggleRow: some View {
        settingsRow {
            Text("Sync preferences across Macs")
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Toggle("", isOn: iCloudSyncBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel("iCloud preferences sync")
        }
    }

    private var syncScopeRow: some View {
        settingsRow {
            VStack(alignment: .leading, spacing: 4) {
                Text("Synced settings")
                    .foregroundStyle(theme.textPrimary)
                Text("Theme · Font size · Accent · Sidebar · Favorites · Recents · Workspace")
                    .foregroundStyle(theme.textMuted)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Synced settings: Theme, Font size, Accent, Sidebar, Favorites, Recents, Workspace")
            Spacer()
        }
    }

    private var syncStatusRow: some View {
        settingsRow {
            Text("Last synced")
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(syncStatusText)
                .foregroundStyle(syncStatusColor)
                .accessibilityLabel(showSyncedPulse ? "Just synced" : "Sync status: \(syncStatusText)")
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
            syncStatusTrailing
        }
    }

    @ViewBuilder
    private var syncStatusTrailing: some View {
        switch cloudSyncStore.status {
        case .syncing:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Syncing")
        case .unavailable:
            Button("Open iCloud Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?iCloud") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .accessibilityHint("Opens iCloud settings to sign in")
        default:
            Button("Sync Now") {
                Task {
                    await cloudSyncStore.syncNow(workspaceStore: workspaceStore)
                }
            }
            .disabled(!workspaceStore.iCloudSyncEnabled)
        }
    }

    private var syncPrivacyNoteRow: some View {
        settingsRow {
            Text("Stored in your private iCloud. PaperEdit and Anthropic never see it. Sign out of iCloud or delete the PaperEditPreferences record from iCloud Settings to remove it.")
                .foregroundStyle(theme.textMuted)
                .font(.system(size: 12))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var syncPathNoteRow: some View {
        settingsRow {
            Text("File shortcuts only appear on this Mac when the path exists locally.")
                .foregroundStyle(theme.textMuted)
                .font(.system(size: 12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var syncStatusText: String {
        switch cloudSyncStore.status {
        case .idle:
            return workspaceStore.iCloudSyncEnabled ? "Not yet synced" : "Off"
        case .syncing:
            return "Syncing…"
        case .synced:
            if showSyncedPulse {
                return "✓ Just now"
            }
            if let lastSyncedAt = cloudSyncStore.lastSyncedAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return formatter.localizedString(for: lastSyncedAt, relativeTo: Date())
            }
            return "Synced"
        case .unavailable(let message), .failed(let message):
            return message
        }
    }

    private var syncStatusColor: Color {
        switch cloudSyncStore.status {
        case .failed, .unavailable:
            return theme.danger
        default:
            return theme.textMuted
        }
    }

    private var iCloudSyncBinding: Binding<Bool> {
        Binding(
            get: { workspaceStore.iCloudSyncEnabled },
            set: { newValue in
                workspaceStore.setICloudSyncEnabled(newValue)
                if newValue {
                    Task { await cloudSyncStore.syncNow(workspaceStore: workspaceStore) }
                }
            }
        )
    }
}

extension ThemePalette: CustomStringConvertible {
    var description: String { displayName }
}

extension SidebarMaterialStyle: CustomStringConvertible {
    var description: String { displayName }
}
