import SwiftUI

struct WorkspaceTitleBar: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore

    let theme: PaperTheme
    let isCompactWidth: Bool
    let topInset: CGFloat
    private let titlebarLeadingInset: CGFloat = 16
    private let titlebarContentHeight: CGFloat = 52

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.windowBackground

            HStack(spacing: 0) {
                leftCluster
                    .padding(.leading, titlebarLeadingInset)

                HairlineDivider(theme: theme)
                    .padding(.horizontal, 12)

                if isCompactWidth {
                    compactTabs
                } else {
                    tabsStrip
                }

                Spacer(minLength: 10)

                rightCluster
                    .padding(.trailing, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 8)

            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
        .frame(height: titlebarContentHeight)
    }

    private var leftCluster: some View {
        HStack(spacing: 10) {
            Menu {
                Button("New File") { workspaceStore.createUntitledTab() }
                Button("Open File...") { workspaceStore.presentOpenPanel() }
                Button("Open Folder...") { workspaceStore.presentOpenFolderPanel() }
            } label: {
                HStack(spacing: 6) {
                    Text("PaperEdit")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.textSubtle)
                }
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 8)
                .frame(height: 28)
            }
            .menuStyle(.borderlessButton)

            HStack(spacing: 6) {
                ToolbarIconButton(symbol: "doc.badge.plus", theme: theme) {
                    workspaceStore.createUntitledTab()
                }
                ToolbarIconButton(symbol: "magnifyingglass", theme: theme) {
                    workspaceStore.openCommandPalette(prefill: "")
                }
                ToolbarIconButton(symbol: "square.and.arrow.up", theme: theme) {
                    _ = workspaceStore.saveActiveTab()
                }
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
            HStack(spacing: 0) {
                ForEach(workspaceStore.openTabs) { tab in
                    TabItemView(tab: tab, theme: theme, isActive: workspaceStore.activeTabID == tab.id)
                }

                Button {
                    workspaceStore.createUntitledTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textMuted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
        .frame(height: 36)
    }

    private var rightCluster: some View {
        HStack(spacing: 10) {
            if workspaceStore.markdownModeAvailable {
                HStack(spacing: 0) {
                    modeButton(.edit, title: "编辑")
                    modeButton(.split, title: "分屏预览")
                    modeButton(.wysiwyg, title: "所见即所得")
                }
                .padding(2)
                .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
            }

            HairlineDivider(theme: theme)

            HStack(spacing: 4) {
                ToolbarIconButton(symbol: "sidebar.right", theme: theme) {
                    workspaceStore.toggleSidebarCollapse()
                }
                ToolbarIconButton(symbol: "rectangle.split.2x1", theme: theme) {
                    workspaceStore.setViewMode(.split)
                }
                ToolbarIconButton(symbol: "ellipsis", theme: theme) {
                    workspaceStore.openCommandPalette()
                }
            }
        }
    }

    private func modeButton(_ mode: EditorViewMode, title: String) -> some View {
        Button {
            workspaceStore.setViewMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(workspaceStore.viewMode == mode ? theme.accent : theme.textMuted)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(workspaceStore.viewMode == mode ? theme.hover : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ToolbarIconButton: View {
    let symbol: String
    let theme: PaperTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .foregroundStyle(theme.textMuted)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
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
        .frame(height: 32)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
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
                .frame(minWidth: 122, maxWidth: 190, minHeight: 32, maxHeight: 32, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? theme.elevatedBackground : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isActive ? theme.border : .clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if hovering || isActive {
                Button {
                    workspaceStore.closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.textMuted)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct HairlineDivider: View {
    let theme: PaperTheme

    var body: some View {
        Rectangle()
            .fill(theme.border)
            .frame(width: 1, height: 20)
    }
}
