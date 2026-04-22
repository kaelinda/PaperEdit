import SwiftUI

struct WorkspaceSidebar: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let theme: PaperTheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textSubtle)

                TextField("Search files", text: $workspaceStore.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textPrimary)

                Text("⌘F")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textSubtle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.border)
                    .frame(height: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SidebarSectionView(theme: theme, section: .pinned, nodes: filtered(nodes: workspaceStore.pinnedFiles))
                    SidebarSectionView(theme: theme, section: .recent, nodes: filtered(nodes: workspaceStore.recentProjects))
                    SidebarSectionView(
                        theme: theme,
                        section: .explorer,
                        nodes: filtered(nodes: workspaceStore.explorerFiles),
                        emptyActionTitle: "Open Folder",
                        emptyAction: workspaceStore.presentOpenFolderPanel
                    )
                }
                .padding(.bottom, 16)
            }
        }
        .background(sidebarBackground)
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        if workspaceStore.sidebarMaterialStyle == .translucent {
            ZStack {
                VisualEffectBlur(material: .sidebar)
                theme.sidebarBackground.opacity(0.97)
            }
        } else {
            theme.sidebarBackground
        }
    }

    private func filtered(nodes: [FileTreeNode]) -> [FileTreeNode] {
        let query = workspaceStore.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nodes }

        return nodes.compactMap { node in
            filter(node: node, query: query.lowercased())
        }
    }

    private func filter(node: FileTreeNode, query: String) -> FileTreeNode? {
        let matches = node.name.lowercased().contains(query)
        let filteredChildren = node.children.compactMap { filter(node: $0, query: query) }
        if matches || !filteredChildren.isEmpty {
            return FileTreeNode(
                id: node.id,
                name: node.name,
                kind: node.kind,
                format: node.format,
                sourceURL: node.sourceURL,
                children: filteredChildren
            )
        }
        return nil
    }
}

private struct SidebarSectionView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let theme: PaperTheme
    let section: SidebarSection
    let nodes: [FileTreeNode]
    var emptyActionTitle: String? = nil
    var emptyAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                workspaceStore.toggleSidebarSection(section)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: workspaceStore.sidebarSections.contains(section) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                    Image(systemName: section.iconName)
                        .font(.system(size: 10, weight: .semibold))
                    Text(section.title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.9)
                    Spacer()
                }
                .foregroundStyle(theme.textMuted)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            if workspaceStore.sidebarSections.contains(section) {
                if nodes.isEmpty {
                    if let emptyActionTitle, let emptyAction {
                        Button(action: emptyAction) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 12, weight: .medium))
                                Text(emptyActionTitle)
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                            }
                            .foregroundStyle(theme.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(emptyStateCopy)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(nodes) { node in
                            FileTreeNodeRow(node: node, depth: 0, theme: theme)
                        }
                    }
                }
            }
        }
    }

    private var emptyStateCopy: String {
        switch section {
        case .pinned:
            "No open documents."
        case .recent:
            "Files you open will appear here."
        case .explorer:
            "Open a folder to browse files."
        }
    }
}

private struct FileTreeNodeRow: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
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
            Button {
                switch node.kind {
                case .file:
                    workspaceStore.openFileTreeNode(node)
                case .folder, .group:
                    workspaceStore.toggleNodeExpansion(node.id)
                case .project:
                    break
                }
            } label: {
                HStack(spacing: 8) {
                    if isContainer {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.textMuted)
                            .frame(width: 10)
                    } else {
                        Spacer()
                            .frame(width: 10)
                    }

                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(width: 14)

                    Text(node.name)
                        .lineLimit(1)
                        .font(.system(size: 13, weight: node.kind == .group ? .medium : .regular))
                        .foregroundStyle(theme.textPrimary.opacity(node.kind == .project ? 0.9 : 1))

                    Spacer(minLength: 0)
                }
                .padding(.leading, CGFloat(depth) * 14 + 12)
                .padding(.trailing, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? theme.hover : .clear)
                )
            }
            .buttonStyle(.plain)

            if isExpanded, !node.children.isEmpty {
                ForEach(node.children) { child in
                    FileTreeNodeRow(node: child, depth: depth + 1, theme: theme)
                }
            }
        }
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
            Color(hex: node.format?.accentHex ?? "#8E8E93")
        case .folder:
            theme.accent
        case .group, .project:
            theme.textMuted
        }
    }
}
