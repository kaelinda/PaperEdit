import SwiftUI

struct WorkspaceTitleBar: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var settingsModel: SettingsWindowModel

    let theme: PaperTheme
    let isCompactWidth: Bool
    let topInset: CGFloat
    private let horizontalInset: CGFloat = 18
    private let titlebarContentHeight: CGFloat = 46

    var body: some View {
        ZStack(alignment: .bottom) {
            LiquidGlassChrome(theme: theme)

            VStack(spacing: 0) {
                Spacer(minLength: titlebarTopPadding)

                HStack(spacing: isCompactWidth ? 8 : 12) {
                    leftCluster
                        .layoutPriority(3)
                        .fixedSize(horizontal: true, vertical: false)

                    if !isCompactWidth {
                        HairlineDivider(theme: theme)
                    }

                    Group {
                        if isCompactWidth {
                            compactTabs
                        } else {
                            tabsStrip
                        }
                    }

                    Spacer(minLength: 12)

                    rightCluster
                        .layoutPriority(3)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, horizontalInset)
                .frame(height: titlebarContentHeight)
            }

            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
        .frame(height: titlebarContentHeight + titlebarTopPadding)
    }

    private var titlebarTopPadding: CGFloat {
        guard topInset > 0 else { return 8 }
        return max(18, min(24, topInset - 54))
    }

    private var leftCluster: some View {
        HStack(spacing: isCompactWidth ? 6 : 10) {
            HStack(spacing: isCompactWidth ? 0 : 9) {
                AppLogoMark(theme: theme)
                    .frame(width: 30, height: 30)

                if !isCompactWidth {
                    Text("PaperEdit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                }
            }
            .padding(.horizontal, isCompactWidth ? 4 : 7)
            .frame(height: 36)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("PaperEdit")
            .accessibilityValue(workspaceCaption)
            .help("Current workspace")

            HStack(spacing: 1) {
                Menu {
                    Button("New File") { workspaceStore.createUntitledTab() }
                    Divider()
                    Button("Open File...") { workspaceStore.presentOpenPanel() }
                    Button("Open Folder...") { workspaceStore.presentOpenFolderPanel() }
                } label: {
                    ToolbarActionLabel(symbol: "folder", title: "Open", theme: theme, trailingSymbol: "chevron.down", compact: isCompactWidth)
                }
                .menuStyle(.borderlessButton)
                .help("Open a file or folder")

                Button {
                    workspaceStore.openQuickOpen()
                } label: {
                    ToolbarActionLabel(symbol: "magnifyingglass", title: "Find", theme: theme, shortcut: "⌘P", compact: isCompactWidth)
                }
                .buttonStyle(.plain)
                .help("Find a file in the current workspace")

                Button {
                    _ = workspaceStore.saveActiveTab()
                } label: {
                    ToolbarActionLabel(symbol: "square.and.arrow.down", title: "Save", theme: theme, compact: isCompactWidth)
                }
                .buttonStyle(.plain)
                .disabled(workspaceStore.activeTab == nil)
                .help("Save current file")
            }
            .padding(3)
            .background(toolbarSurface(cornerRadius: 10))
        }
    }

    private var compactTabs: some View {
        HStack(spacing: 8) {
            if let activeTab = workspaceStore.activeTab {
                TabChip(tab: activeTab, theme: theme, isActive: true)
            } else {
                Text("No file open")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
            }
        }
    }

    private var tabsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(workspaceStore.openTabs) { tab in
                    TabItemView(tab: tab, theme: theme, isActive: workspaceStore.activeTabID == tab.id)
                }

                Button {
                    workspaceStore.createUntitledTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textMuted)
                        .frame(width: 26, height: 26)
                        .background(theme.hover, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.leading, 2)
                .accessibilityLabel("New File")
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
        }
        .frame(minWidth: 230, idealWidth: 360, maxWidth: 520)
        .frame(height: 36)
        .background(toolbarSurface(cornerRadius: 11))
        .layoutPriority(0)
    }

    private var rightCluster: some View {
        HStack(spacing: 8) {
            if workspaceStore.previewModeAvailable {
                HStack(spacing: 1) {
                    modeButton(.edit, title: "编辑")
                    modeButton(.split, title: "分屏预览")
                    modeButton(.wysiwyg, title: "预览")
                }
                .padding(3)
                .background(toolbarSurface(cornerRadius: 10))
            }

            HStack(spacing: 2) {
                ToolbarIconButton(
                    symbol: themeToggleSymbol,
                    theme: theme,
                    accessibilityLabel: themeToggleAccessibilityLabel
                ) {
                    workspaceStore.toggleTheme()
                }
                ToolbarIconButton(
                    symbol: "sidebar.right",
                    theme: theme,
                    isActive: workspaceStore.sidebarWidth > 0,
                    accessibilityLabel: "Toggle Sidebar"
                ) {
                    workspaceStore.toggleSidebarCollapse()
                }
                ToolbarIconButton(symbol: "rectangle.split.2x1", theme: theme) {
                    workspaceStore.setViewMode(.split)
                }
                .accessibilityLabel("Show Split Preview")
                ToolbarIconButton(symbol: "gearshape", theme: theme) {
                    settingsModel.selectedPane = .appearance
                    workspaceStore.showSettings = true
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .accessibilityLabel("Open Settings")
                .help("Open Settings")
                ToolbarIconButton(symbol: "ellipsis", theme: theme) {
                    workspaceStore.openCommandPalette()
                }
                .accessibilityLabel("Open Command Palette")
            }
            .padding(3)
            .background(toolbarSurface(cornerRadius: 10))
        }
    }

    private var themeToggleSymbol: String {
        switch workspaceStore.themeMode {
        case .dark:
            "sun.max"
        case .light, .system:
            "moon"
        }
    }

    private var themeToggleAccessibilityLabel: String {
        switch workspaceStore.themeMode {
        case .dark:
            "Switch to Light Mode"
        case .light, .system:
            "Switch to Dark Mode"
        }
    }

    private func modeButton(_ mode: EditorViewMode, title: String) -> some View {
        let isSelected = workspaceStore.viewMode == mode

        return Button {
            workspaceStore.setViewMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 13)
                .frame(minHeight: 34)
                .background(
                    Group {
                        if isSelected {
                            LiquidGlassSurface(theme: theme, cornerRadius: 8, isProminent: true)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "")
        .fixedSize(horizontal: true, vertical: false)
    }
    private var workspaceCaption: String {
        if let url = workspaceStore.workspaceRootURL {
            return url.lastPathComponent
        }
        if let activeTab = workspaceStore.activeTab {
            return activeTab.name
        }
        return "Document workspace"
    }

    private func toolbarSurface(cornerRadius: CGFloat) -> some View {
        LiquidGlassSurface(theme: theme, cornerRadius: cornerRadius)
    }
}

private struct AppLogoMark: View {
    let theme: PaperTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.96), Color(hex: "#E9ECF4")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: theme.shadow.opacity(0.18), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Capsule().fill(theme.accent).frame(width: 11, height: 2.5)
                    Capsule().fill(Color(hex: "#D9DCE3")).frame(width: 5, height: 2.5)
                }
                Capsule().fill(Color(hex: "#FFCC11")).frame(width: 17, height: 2.5)
                HStack(spacing: 3) {
                    Capsule().fill(Color(hex: "#B24EE7")).frame(width: 13, height: 2.5)
                    Capsule().fill(Color(hex: "#D9DCE3")).frame(width: 5, height: 2.5)
                }
                Capsule().fill(Color(hex: "#36D344")).frame(width: 19, height: 2.5)
                HStack(spacing: 3) {
                    Capsule().fill(Color(hex: "#FF930F")).frame(width: 9, height: 2.5)
                    Capsule().fill(Color(hex: "#FF2D55")).frame(width: 8, height: 2.5)
                }
            }
            .padding(.top, 1)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.selectedItemFill)
                .frame(width: 36, height: 36)
        )
        .accessibilityHidden(true)
    }
}

private struct ToolbarIconButton: View {
    let symbol: String
    let theme: PaperTheme
    var isActive = false
    var accessibilityLabel: String?
    let action: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(ToolbarIconButtonStyle(theme: theme, hovering: hovering, focused: focused, isActive: isActive))
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .focusable()
        .focused($focused)
        .onHover { isHovering in
            withAnimation(.easeOut(duration: 0.14)) {
                hovering = isHovering
            }
        }
        .accessibilityLabel(accessibilityLabel ?? symbol)
        .accessibilityValue(isActive ? "Active" : "")
    }
}

private struct ToolbarIconButtonStyle: ButtonStyle {
    let theme: PaperTheme
    let hovering: Bool
    let focused: Bool
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .foregroundStyle(foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(focused ? theme.accent : isActive ? theme.selectedItemStroke : .clear, lineWidth: focused ? 2 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.78, blendDuration: 0.04), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.14), value: hovering)
            .animation(.easeOut(duration: 0.12), value: focused)
            .animation(.easeOut(duration: 0.18), value: isActive)
    }

    private var foregroundColor: Color {
        if isActive {
            return theme.accent
        }
        return hovering || focused ? theme.textPrimary : theme.textMuted
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return theme.pressed
        }
        if isActive {
            return theme.selectedItemFill
        }
        return hovering || focused ? theme.hover : .clear
    }
}

private struct ToolbarActionLabel: View {
    let symbol: String
    let title: String
    let theme: PaperTheme
    var trailingSymbol: String?
    var shortcut: String?
    var compact = false
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 14)

            if !compact {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(foregroundColor.opacity(0.66))
                        .padding(.leading, 1)
                }
            }

            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(foregroundColor.opacity(0.7))
            }
        }
        .foregroundStyle(foregroundColor)
        .frame(minHeight: 34)
        .padding(.horizontal, compact ? 7 : 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering && isEnabled ? theme.hover : .clear)
        )
        .opacity(isEnabled ? 1 : 0.46)
        .onHover { hovering = $0 }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var foregroundColor: Color {
        isEnabled ? theme.textPrimary : theme.textMuted
    }
}

private struct TabChip: View {
    let tab: EditorTab
    let theme: PaperTheme
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tab.format.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: tab.format.accentHex))

            Text(tab.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isActive ? theme.textPrimary : theme.textMuted)

            if tab.isDirty {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.elevatedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
    }
}

private struct TabItemView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @State private var hovering = false
    @FocusState private var focused: Bool

    let tab: EditorTab
    let theme: PaperTheme
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                workspaceStore.setActiveTab(tab.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: tab.format.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: tab.format.accentHex))

                    Text(tab.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isActive ? theme.textPrimary : theme.textMuted)

                    if tab.isDirty {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 5, height: 5)
                    }

                    Spacer(minLength: hovering || isActive || focused ? 18 : 0)
                }
                .padding(.horizontal, 12)
                .frame(minWidth: 118, maxWidth: 182, minHeight: 34, maxHeight: 34, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? theme.elevatedBackground : hovering || focused ? theme.hover.opacity(0.72) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(focused ? theme.accent : isActive ? theme.borderStrong : .clear, lineWidth: focused ? 2 : 1)
                )
                .shadow(color: isActive ? theme.shadow.opacity(0.12) : .clear, radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .focusable()
            .focused($focused)

            if hovering || isActive || focused {
                Button {
                    workspaceStore.closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.textMuted)
                        .frame(width: 26, height: 26)
                        .background(theme.hover, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .accessibilityLabel("Close \(tab.name)")
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct HairlineDivider: View {
    let theme: PaperTheme

    var body: some View {
        Rectangle()
            .fill(theme.border)
            .frame(width: 1, height: 18)
    }
}
