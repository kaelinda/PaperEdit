import SwiftUI

struct WorkspaceSidebar: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let theme: PaperTheme

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Files")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
                    .tracking(0.35)

                searchField

                if workspaceStore.showQuickOpen {
                    QuickOpenPanelView(theme: theme)
                        .transition(.opacity)
                        .zIndex(1)
                }

                if let workspaceRootURL = workspaceStore.workspaceRootURL {
                    HStack(spacing: 7) {
                        Image(systemName: "folder")
                            .font(.system(size: 12, weight: .medium))
                        Text(workspaceRootURL.lastPathComponent)
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textSubtle)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.border)
                    .frame(height: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SidebarSectionView(theme: theme, section: .favorites, nodes: workspaceStore.favoriteFiles)
                    SidebarSectionView(theme: theme, section: .recent, nodes: workspaceStore.recentProjects)
                    SidebarSectionView(
                        theme: theme,
                        section: .explorer,
                        nodes: workspaceStore.explorerFiles,
                        emptyActionTitle: "Open Folder",
                        emptyAction: workspaceStore.presentOpenFolderPanel
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 18)
            }
        }
        .background(sidebarBackground)
    }

    private var searchField: some View {
        Button {
            workspaceStore.openQuickOpen(prefill: workspaceStore.quickOpenModel.query)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textSubtle)

                Text(quickOpenEntryTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(workspaceStore.quickOpenModel.query.isEmpty ? theme.textMuted : theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("⌘P")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSubtle)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(theme.secondaryElevatedBackground, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(workspaceStore.showQuickOpen ? theme.selectedItemStroke : theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var quickOpenEntryTitle: String {
        let query = workspaceStore.quickOpenModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? "Search files" : query
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        if workspaceStore.sidebarMaterialStyle == .translucent {
            ZStack {
                VisualEffectBlur(material: .sidebar)
                theme.sidebarBackground.opacity(0.92)
            }
        } else {
            theme.sidebarBackground
        }
    }

}

private struct SidebarSectionView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let theme: PaperTheme
    let section: SidebarSection
    let nodes: [FileTreeNode]
    var emptyActionTitle: String? = nil
    var emptyAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(sidebarAnimation) {
                    workspaceStore.toggleSidebarSection(section)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: workspaceStore.sidebarSections.contains(section) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 12)
                    Text(section.title)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.55)
                    Spacer()
                }
                .foregroundStyle(theme.textMuted)
                .padding(.horizontal, 8)
                .frame(height: 24)
            }
            .buttonStyle(.plain)

            if workspaceStore.sidebarSections.contains(section) {
                Group {
                    if nodes.isEmpty {
                        sectionEmptyState
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(nodes) { node in
                                FileTreeNodeRow(node: node, depth: 0, theme: theme)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(sidebarAnimation, value: workspaceStore.sidebarSections.contains(section))
    }

    @ViewBuilder
    private var sectionEmptyState: some View {
        if let emptyActionTitle, let emptyAction {
            Button(action: emptyAction) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12, weight: .medium))
                    Text(emptyActionTitle)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(theme.textMuted)
                .padding(.horizontal, 12)
                .frame(height: 32)
            }
            .buttonStyle(.plain)
        } else {
            Text(emptyStateCopy)
                .font(.system(size: 13))
                .foregroundStyle(theme.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
        }
    }

    private var emptyStateCopy: String {
        switch section {
        case .favorites:
            "Pin the files you revisit often."
        case .recent:
            "Files you open will appear here."
        case .explorer:
            "Open a folder to browse files."
        }
    }

    private var sidebarAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.26, dampingFraction: 0.88, blendDuration: 0.06)
    }
}

private struct FileTreeNodeRow: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    let node: FileTreeNode
    let depth: Int
    let theme: PaperTheme

    private var isExpanded: Bool {
        workspaceStore.expandedNodeIDs.contains(node.id)
    }

    private var isContainer: Bool {
        node.kind == .folder || node.kind == .group
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Button(action: primaryAction) {
                    HStack(spacing: 9) {
                        if isContainer {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.textMuted)
                                .frame(width: 12)
                        } else {
                            Spacer()
                                .frame(width: 12)
                        }

                        Image(systemName: iconName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(iconColor)
                            .frame(width: 16)

                        Text(node.name)
                            .lineLimit(1)
                            .font(.system(size: 13, weight: node.kind == .group || node.kind == .project ? .medium : .regular))
                            .foregroundStyle(theme.textPrimary.opacity(node.kind == .project ? 0.9 : 1))

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(node.kind == .project)

                if let sourceURL = node.sourceURL, node.kind == .file, hovering || workspaceStore.isFavorite(sourceURL) {
                    Button {
                        workspaceStore.toggleFavorite(sourceURL)
                    } label: {
                        Image(systemName: workspaceStore.isFavorite(sourceURL) ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(workspaceStore.isFavorite(sourceURL) ? theme.accent : theme.textSubtle)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .padding(.leading, CGFloat(depth) * 13 + 10)
            .padding(.trailing, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? theme.selectedItemFill : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? theme.selectedItemStroke : .clear, lineWidth: 1)
            )
            .onHover { hovering = $0 }

            if isExpanded, !node.children.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(node.children) { child in
                        FileTreeNodeRow(node: child, depth: depth + 1, theme: theme)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(sidebarAnimation, value: isExpanded)
    }

    private var iconName: String {
        switch node.kind {
        case .file:
            node.format?.iconName ?? "doc"
        case .folder:
            "folder"
        case .group:
            "folder.badge.minus"
        case .project:
            "folder.fill"
        }
    }

    private var isSelected: Bool {
        guard node.kind == .file else { return false }
        if let sourceURL = node.sourceURL {
            return workspaceStore.activeTab?.sourceURL == sourceURL
        }
        return workspaceStore.activeTab?.name == node.name
    }

    private var iconColor: Color {
        switch node.kind {
        case .file:
            Color(hex: node.format?.accentHex ?? "#8E8E93").opacity(0.82)
        case .folder:
            Color(hex: "#4F8FF7").opacity(0.9)
        case .group:
            theme.textSubtle
        case .project:
            theme.textPrimary
        }
    }

    private func primaryAction() {
        switch node.kind {
        case .file:
            workspaceStore.openFileTreeNode(node)
        case .folder, .group:
            withAnimation(sidebarAnimation) {
                workspaceStore.toggleNodeExpansion(node.id)
            }
        case .project:
            break
        }
    }

    private var sidebarAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.24, dampingFraction: 0.86, blendDuration: 0.05)
    }
}
