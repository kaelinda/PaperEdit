import AppKit
import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let theme: PaperTheme
    let isDropTargeted: Bool

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 880

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: isCompact ? 22 : 24) {
                    heroPanel(isCompact: isCompact)
                }
                .padding(.horizontal, isCompact ? 28 : 64)
                .padding(.vertical, isCompact ? 34 : 56)
                .frame(maxWidth: isCompact ? 440 : 540, minHeight: proxy.size.height, alignment: .center)
                .frame(maxWidth: .infinity)
            }
            .background(theme.canvasBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isDropTargeted ? theme.selectedItemStroke : .clear, lineWidth: 2)
                    .padding(22)
            }
        }
    }

    private func heroPanel(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 20 : 22) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .frame(width: 38, height: 38)
                    .background(theme.selectedItemFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Open a file to begin.")
                    .font(.system(size: isCompact ? 22 : 24, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Text("Drop files here, or choose a document from the sidebar.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isCompact {
                VStack(alignment: .leading, spacing: 10) {
                    quickActionButton("Open File...", symbol: "doc.badge.plus", prominent: true) {
                        workspaceStore.presentOpenPanel()
                    }
                    quickActionButton("Open Folder...", symbol: "folder.badge.plus", prominent: false) {
                        workspaceStore.presentOpenFolderPanel()
                    }
                }
            } else {
                HStack(spacing: 10) {
                    quickActionButton("Open File...", symbol: "doc.badge.plus", prominent: true) {
                        workspaceStore.presentOpenPanel()
                    }
                    quickActionButton("Open Folder...", symbol: "folder.badge.plus", prominent: false) {
                        workspaceStore.presentOpenFolderPanel()
                    }
                }
            }

            HStack(spacing: 10) {
                shortcutToken("⌘O", "Open")
                shortcutToken("⌘N", "New")
                shortcutToken("⇧⌘P", "Palette")
            }
            .padding(.top, 2)

            continueSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var continueSection: some View {
        let workspace = workspaceStore.workspaceRootURL
        let recents = Array(workspaceStore.recentFileURLs.prefix(3))
        let favorites = Array(workspaceStore.favoriteFileURLs.prefix(3))

        if workspace != nil || !recents.isEmpty || !favorites.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Continue")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
                    .padding(.top, 6)

                if let workspace {
                    continueRow(title: workspace.lastPathComponent, subtitle: "Workspace", symbol: "folder") {
                        workspaceStore.workspaceRootURL = workspace
                        workspaceStore.expandedNodeIDs.insert(workspace.path)
                    }
                }

                ForEach(recents, id: \.path) { url in
                    continueRow(title: url.lastPathComponent, subtitle: "Recent", symbol: "clock.arrow.circlepath") {
                        workspaceStore.openExternalFiles([url])
                    }
                }

                ForEach(favorites, id: \.path) { url in
                    continueRow(title: url.lastPathComponent, subtitle: "Favorite", symbol: "star") {
                        workspaceStore.openExternalFiles([url])
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func continueRow(title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 24, height: 24)
                    .background(theme.selectedItemFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.textSubtle)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(theme.secondaryElevatedBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.border.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func quickActionButton(_ title: String, symbol: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(prominent ? theme.accentForeground : theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(
                Capsule(style: .continuous)
                    .fill(prominent ? theme.accent : theme.secondaryElevatedBackground)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(prominent ? .clear : theme.border.opacity(0.85), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func shortcutToken(_ shortcut: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(shortcut)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSubtle)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(theme.secondaryElevatedBackground, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(theme.border.opacity(0.55), lineWidth: 1)
        )
    }
}
