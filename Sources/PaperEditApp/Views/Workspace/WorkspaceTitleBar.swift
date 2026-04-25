import SwiftUI

struct WorkspaceTitleBar: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore

    let theme: PaperTheme
    let isCompactWidth: Bool
    let topInset: CGFloat
    private let horizontalInset: CGFloat = 16
    private let titlebarContentHeight: CGFloat = 48

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                VisualEffectBlur(material: .headerView)
                theme.chromeBackground
            }

            VStack(spacing: 0) {
                Spacer(minLength: max(0, topInset - 8))

                HStack(spacing: 14) {
                    leftCluster

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
                }
                .padding(.horizontal, horizontalInset)
                .frame(height: titlebarContentHeight)
            }

            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
        .frame(height: titlebarContentHeight + max(0, topInset - 8))
    }

    private var leftCluster: some View {
        HStack(spacing: 8) {
            Menu {
                Button("New File") { workspaceStore.createUntitledTab() }
                Button("Open File...") { workspaceStore.presentOpenPanel() }
                Button("Open Folder...") { workspaceStore.presentOpenFolderPanel() }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.14))
                        Image(systemName: "doc.text")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                    .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("PaperEdit")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                        Text(workspaceCaption)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.textSubtle)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.textSubtle)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(toolbarCapsuleBackground)
            }
            .menuStyle(.borderlessButton)
            .help("PaperEdit menu")

            HStack(spacing: 4) {
                Menu {
                    Button("New File") { workspaceStore.createUntitledTab() }
                    Divider()
                    Button("Open File...") { workspaceStore.presentOpenPanel() }
                    Button("Open Folder...") { workspaceStore.presentOpenFolderPanel() }
                } label: {
                    ToolbarActionLabel(symbol: "folder", title: "Open", theme: theme, trailingSymbol: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .help("Open a file or folder")

                Button {
                    workspaceStore.openQuickOpen()
                } label: {
                    ToolbarActionLabel(symbol: "magnifyingglass", title: "Find", theme: theme, shortcut: "⌘P")
                }
                .buttonStyle(.plain)
                .help("Find a file in the current workspace")

                Button {
                    _ = workspaceStore.saveActiveTab()
                } label: {
                    ToolbarActionLabel(symbol: "square.and.arrow.down", title: "Save", theme: theme)
                }
                .buttonStyle(.plain)
                .disabled(workspaceStore.activeTab == nil)
                .help("Save current file")
            }
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
            HStack(spacing: 4) {
                ForEach(workspaceStore.openTabs) { tab in
                    TabItemView(tab: tab, theme: theme, isActive: workspaceStore.activeTabID == tab.id)
                }

                Button {
                    workspaceStore.createUntitledTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textMuted)
                        .frame(width: 28, height: 28)
                        .background(theme.hover, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(4)
        }
        .frame(height: 40)
        .background(toolbarCapsuleBackground)
    }

    private var rightCluster: some View {
        HStack(spacing: 10) {
            if workspaceStore.previewModeAvailable {
                HStack(spacing: 0) {
                    modeButton(.edit, title: "编辑")
                    modeButton(.split, title: "分屏预览")
                    modeButton(.wysiwyg, title: "预览")
                }
                .padding(3)
                .background(toolbarCapsuleBackground)
            }

            HStack(spacing: 4) {
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
                ToolbarIconButton(symbol: "ellipsis", theme: theme) {
                    workspaceStore.openCommandPalette()
                }
            }
            .padding(4)
            .background(toolbarCapsuleBackground)
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
        Button {
            workspaceStore.setViewMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(workspaceStore.viewMode == mode ? theme.textPrimary : theme.textMuted)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(workspaceStore.viewMode == mode ? theme.elevatedBackground : .clear)
                        .shadow(
                            color: workspaceStore.viewMode == mode ? theme.shadow.opacity(0.18) : .clear,
                            radius: 10,
                            y: 4
                        )
                )
        }
        .buttonStyle(.plain)
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

    private var toolbarCapsuleBackground: some View {
        Capsule(style: .continuous)
            .fill(theme.secondaryElevatedBackground)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}

private struct ToolbarIconButton: View {
    let symbol: String
    let theme: PaperTheme
    var isActive = false
    var accessibilityLabel: String?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(ToolbarIconButtonStyle(theme: theme, hovering: hovering, isActive: isActive))
        .contentShape(Circle())
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
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 30, height: 30)
            .foregroundStyle(foregroundColor)
            .background(
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                Circle()
                    .stroke(isActive ? theme.selectedItemStroke : .clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : hovering ? 1.035 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.78, blendDuration: 0.04), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.14), value: hovering)
            .animation(.easeOut(duration: 0.18), value: isActive)
    }

    private var foregroundColor: Color {
        if isActive {
            return theme.accent
        }
        return hovering ? theme.textPrimary : theme.textMuted
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return theme.pressed
        }
        if isActive {
            return theme.selectedItemFill
        }
        return hovering ? theme.hover : .clear
    }
}

private struct ToolbarActionLabel: View {
    let symbol: String
    let title: String
    let theme: PaperTheme
    var trailingSymbol: String?
    var shortcut: String?
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 14)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            if let shortcut {
                Text(shortcut)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(foregroundColor.opacity(0.66))
                    .padding(.leading, 1)
            }

            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(foregroundColor.opacity(0.7))
            }
        }
        .foregroundStyle(foregroundColor)
        .frame(height: 30)
        .padding(.horizontal, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering && isEnabled ? theme.hover : theme.secondaryElevatedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .opacity(isEnabled ? 1 : 0.46)
        .onHover { hovering = $0 }
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
                .foregroundStyle(isActive ? theme.textPrimary : theme.textMuted)

            if tab.isDirty {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(
            Capsule(style: .continuous)
                .fill(theme.elevatedBackground)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
    }
}

private struct TabItemView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @State private var hovering = false

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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isActive ? theme.textPrimary : theme.textMuted)

                    if tab.isDirty {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 5, height: 5)
                    }

                    Spacer(minLength: hovering || isActive ? 16 : 0)
                }
                .padding(.horizontal, 12)
                .frame(minWidth: 118, maxWidth: 182, minHeight: 30, maxHeight: 30, alignment: .leading)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? theme.elevatedBackground : hovering ? theme.hover.opacity(0.72) : .clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isActive ? theme.borderStrong : .clear, lineWidth: 1)
                )
                .shadow(color: isActive ? theme.shadow.opacity(0.12) : .clear, radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            if hovering || isActive {
                Button {
                    workspaceStore.closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.textMuted)
                        .frame(width: 18, height: 18)
                        .background(theme.hover, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
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
