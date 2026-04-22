import SwiftUI

struct SettingsRootView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var settingsModel: SettingsWindowModel
    @Environment(\.colorScheme) private var colorScheme

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
                Button("Restore Defaults") {}
                    .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.bordered)

                Button("OK") {
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
                labeledValueRow("Startup", value: "Restore previous tabs")
                labeledValueRow("Default open behavior", value: "Last workspace")
            }
        case .editor:
            settingsCard("Text") {
                valueStepperRow("Font size", value: "14")
                valueStepperRow("Line height", value: "1.6")
            }

            settingsCard("Code Editing") {
                toggleRow("Show line numbers", true)
                toggleRow("Highlight current line", true)
                toggleRow("Word wrap", false)
                valueStepperRow("Tab width", value: "4")
            }

            settingsCard("Behavior") {
                toggleRow("Auto closing brackets", true)
                toggleRow("Auto indentation", true)
            }
        case .appearance:
            settingsCard("Theme") {
                labeledPickerRow("Color Theme", selection: $workspaceStore.themeMode, values: ThemePalette.allCases)
                accentRow
                labeledPickerRow("Sidebar Material", selection: $workspaceStore.sidebarMaterialStyle, values: SidebarMaterialStyle.allCases)
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
            Spacer()
            Text(value)
                .foregroundStyle(theme.textMuted)
        }
    }

    private func valueStepperRow(_ title: String, value: String) -> some View {
        settingsRow {
            Text(title)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            HStack(spacing: 10) {
                Text(value)
                    .foregroundStyle(theme.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textSubtle)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(theme.windowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
    }

    private func toggleRow(_ title: String, _ isOn: Bool) -> some View {
        settingsRow {
            Text(title)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
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
                        workspaceStore.accentSwatch = swatch
                    } label: {
                        Circle()
                            .fill(swatch.displayColor)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(workspaceStore.accentSwatch == swatch ? theme.textPrimary : .clear, lineWidth: 2)
                                    .padding(-4)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func labeledPickerRow<T: CaseIterable & Hashable>(_ title: String, selection: Binding<T>, values: T.AllCases) -> some View where T.AllCases: RandomAccessCollection, T: CustomStringConvertible {
        settingsRow {
            Text(title)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(Array(values), id: \.self) { value in
                    Text(value.description).tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
        }
    }

    private func shortcutRow(_ title: String, _ shortcut: String) -> some View {
        settingsRow {
            Text(title)
                .foregroundStyle(theme.textPrimary)
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
            .frame(height: 44)

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
}

extension ThemePalette: CustomStringConvertible {
    var description: String { displayName }
}

extension SidebarMaterialStyle: CustomStringConvertible {
    var description: String { displayName }
}
