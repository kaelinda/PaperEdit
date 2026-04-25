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
                Button("Restore Defaults") {
                    workspaceStore.resetInterfacePreferences()
                }
                    .buttonStyle(.bordered)
                    .help("Restore appearance and editor preferences")

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
}

extension ThemePalette: CustomStringConvertible {
    var description: String { displayName }
}

extension SidebarMaterialStyle: CustomStringConvertible {
    var description: String { displayName }
}
