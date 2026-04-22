import AppKit
import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let theme: PaperTheme
    let isDropTargeted: Bool

    var body: some View {
        HStack(spacing: 0) {
            emptySidebar
                .frame(width: 240)

            VStack {
                Spacer()

                VStack(spacing: 22) {
                    Image(systemName: "document")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(theme.textSubtle.opacity(0.9))

                    VStack(spacing: 8) {
                        Text("Open a file or drop one here")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)

                        Text("Drag and drop a file anywhere in this window to open it.")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textMuted)
                    }

                    shortcutGrid

                    Label("Supports Markdown, JSON, YAML, TOML, and more", systemImage: "square.and.arrow.down.on.square")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.textMuted)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )
                }
                .frame(maxWidth: 640)
                .padding(.horizontal, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.editorBackground)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDropTargeted ? theme.selection : .clear)
                .padding(24)
        )
    }

    private var emptySidebar: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)

            sidebarBlock(
                title: "Recent",
                body: AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(theme.textSubtle)
                        Text(workspaceStore.recentFileURLs.isEmpty ? "No recent files yet" : "Recent files are available")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.textMuted)
                        Button("Open File...") {
                            workspaceStore.presentOpenPanel()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 18)
                )
            )

            sidebarBlock(
                title: "Workspace",
                body: AnyView(
                    VStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(theme.textSubtle)
                        Text(workspaceStore.workspaceRootURL == nil ? "No workspace folder" : workspaceStore.workspaceRootURL?.lastPathComponent ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.textMuted)
                        Button("Open Folder...") {
                            workspaceStore.presentOpenFolderPanel()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 18)
                )
            )

            Spacer()
        }
        .background(theme.sidebarBackground)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textSubtle)

            Text("Search files...")
                .font(.system(size: 13))
                .foregroundStyle(theme.textMuted)

            Spacer()

            Text("⌘F")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSubtle)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private var shortcutGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                shortcutCell("⌘ O", title: "Open File")
                shortcutCell("⌘ ⇧ P", title: "Command Palette")
            }
            Divider().overlay(theme.border)
            HStack(spacing: 0) {
                shortcutCell("⌘ N", title: "New File")
                shortcutCell("⌘ ,", title: "Preferences")
            }
        }
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private func shortcutCell(_ shortcut: String, title: String) -> some View {
        HStack(spacing: 16) {
            Text(shortcut)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 64, alignment: .leading)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textMuted)

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(width: 264, height: 44, alignment: .leading)
    }

    private func sidebarBlock(title: String, body: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(theme.textMuted)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            body
                .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
    }
}
