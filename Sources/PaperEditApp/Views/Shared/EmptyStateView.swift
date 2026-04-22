import AppKit
import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let theme: PaperTheme
    let isDropTargeted: Bool

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 720

            Group {
                if isCompact {
                    ScrollView {
                        VStack(spacing: 0) {
                            mainEmptyContent(isCompact: true)
                                .padding(.vertical, 40)

                            emptySidebar
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 24)
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        emptySidebar
                            .frame(width: 240)

                        VStack {
                            Spacer()
                            mainEmptyContent(isCompact: false)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.editorBackground)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isDropTargeted ? theme.selection : .clear)
                    .padding(24)
            )
        }
    }

    private func mainEmptyContent(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 18 : 22) {
            Image(systemName: "document")
                .font(.system(size: isCompact ? 52 : 72, weight: .ultraLight))
                .foregroundStyle(theme.textSubtle.opacity(0.9))

            VStack(spacing: 8) {
                Text("Open a file or drop one here")
                    .font(.system(size: isCompact ? 20 : 22, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Text("Drag and drop a file anywhere in this window to open it.")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textMuted)
                    .multilineTextAlignment(.center)
            }

            shortcutGrid(isCompact: isCompact)

            Label("Supports Markdown, JSON, YAML, TOML, and more", systemImage: "square.and.arrow.down.on.square")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textMuted)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: isCompact ? 520 : 640)
        .padding(.horizontal, isCompact ? 18 : 24)
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
                    VStack(spacing: 8) {
                        if filteredRecentFiles.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(theme.textSubtle)
                                Text(recentEmptyCopy)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(theme.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 18)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(filteredRecentFiles.prefix(5), id: \.self) { url in
                                    recentFileButton(url)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Button("Open File...") {
                            workspaceStore.presentOpenPanel()
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, filteredRecentFiles.isEmpty ? 0 : 6)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
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

            TextField("Search recent files", text: $workspaceStore.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(theme.textPrimary)

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

    private var filteredRecentFiles: [URL] {
        let query = workspaceStore.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return workspaceStore.recentFileURLs }
        return workspaceStore.recentFileURLs.filter { url in
            url.lastPathComponent.lowercased().contains(query)
                || url.deletingLastPathComponent().path.lowercased().contains(query)
        }
    }

    private var recentEmptyCopy: String {
        workspaceStore.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No recent files yet"
            : "No matching recent files"
    }

    private func recentFileButton(_ url: URL) -> some View {
        Button {
            workspaceStore.openExternalFiles([url])
        } label: {
            HStack(spacing: 8) {
                Image(systemName: EditorFileFormat(fileExtension: url.pathExtension).iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: EditorFileFormat(fileExtension: url.pathExtension).accentHex))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text(url.deletingLastPathComponent().lastPathComponent)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textSubtle)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(minHeight: 44)
            .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.border.opacity(0.75), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shortcutGrid(isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            if isCompact {
                shortcutCell("⌘ O", title: "Open File")
                Divider().overlay(theme.border)
                shortcutCell("⌘ N", title: "New File")
                Divider().overlay(theme.border)
                shortcutCell("⌘ ⇧ P", title: "Command Palette")
                Divider().overlay(theme.border)
                shortcutCell("⌘ ,", title: "Preferences")
            } else {
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
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44, alignment: .leading)
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
