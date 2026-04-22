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
                VStack(spacing: isCompact ? 18 : 24) {
                    heroPanel(isCompact: isCompact)

                    if !workspaceStore.recentFileURLs.isEmpty || workspaceStore.workspaceRootURL != nil {
                        secondaryPanel(isCompact: isCompact)
                    }
                }
                .padding(.horizontal, isCompact ? 20 : 32)
                .padding(.vertical, isCompact ? 20 : 30)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .background(theme.canvasBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(isDropTargeted ? theme.selectedItemStroke : .clear, lineWidth: 2)
                    .padding(18)
            }
        }
    }

    private func heroPanel(isCompact: Bool) -> some View {
        VStack {
            Spacer(minLength: isCompact ? 8 : 20)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(theme.selectedItemFill)
                        Image(systemName: "doc.text.image")
                            .font(.system(size: isCompact ? 26 : 32, weight: .medium))
                            .foregroundStyle(theme.accent)
                    }
                    .frame(width: isCompact ? 64 : 76, height: isCompact ? 64 : 76)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("A quieter place to start.")
                            .font(.system(size: isCompact ? 26 : 32, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)

                        Text("Open a document, attach a folder, or drop files into the editor. The left sidebar already keeps your recent context nearby.")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    quickActionButton("Open File...", symbol: "doc.badge.plus", prominent: true) {
                        workspaceStore.presentOpenPanel()
                    }
                    quickActionButton("Open Folder...", symbol: "folder.badge.plus", prominent: false) {
                        workspaceStore.presentOpenFolderPanel()
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    hintRow(symbol: "command", text: "Open File", shortcut: "O")
                    hintRow(symbol: "command", text: "New File", shortcut: "N")
                    hintRow(symbol: "command", text: "Command Palette", shortcut: "⇧P")
                }
                .padding(16)
                .background(theme.secondaryElevatedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )

                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Markdown, JSON, YAML, TOML and XML render cleanly here.")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(theme.textSubtle)
            }
            .padding(.horizontal, isCompact ? 24 : 42)
            .padding(.vertical, isCompact ? 26 : 36)
            .frame(maxWidth: 760, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(theme.editorBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
            .shadow(color: theme.shadow.opacity(0.12), radius: 24, y: 16)

            Spacer(minLength: isCompact ? 12 : 20)
        }
        .frame(maxWidth: .infinity)
    }

    private func secondaryPanel(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Access")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
                    .tracking(0.6)
                Spacer()
            }

            if isCompact {
                VStack(spacing: 12) {
                    workspaceCard
                    recentFilesCard
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    workspaceCard
                    recentFilesCard
                }
            }
        }
        .padding(.horizontal, isCompact ? 0 : 10)
        .frame(maxWidth: 760)
    }

    private var workspaceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.selectedItemFill)
                    Image(systemName: "folder")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Workspace")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(workspaceStore.workspaceRootURL?.lastPathComponent ?? "No folder attached")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.textSubtle)
                        .lineLimit(1)
                }
            }

            Text(workspaceStore.workspaceRootURL?.path ?? "Attach a directory if you want persistent file browsing in the left sidebar.")
                .font(.system(size: 12))
                .foregroundStyle(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            quickActionButton("Choose Folder", symbol: "folder.badge.plus", prominent: false) {
                workspaceStore.presentOpenFolderPanel()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.secondaryElevatedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private var recentFilesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Files")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            if workspaceStore.recentFileURLs.isEmpty {
                Text("Files you open will appear here for quick access.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(workspaceStore.recentFileURLs.prefix(3)), id: \.self) { url in
                        recentFileButton(url)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.secondaryElevatedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private func recentFileButton(_ url: URL) -> some View {
        let format = EditorFileFormat(fileURL: url)

        return Button {
            workspaceStore.openExternalFiles([url])
        } label: {
            HStack(spacing: 10) {
                Image(systemName: format.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: format.accentHex))
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(theme.editorBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.border.opacity(0.75), lineWidth: 1)
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
            .frame(height: 36)
            .background(
                Capsule(style: .continuous)
                    .fill(prominent ? theme.accent : theme.editorBackground)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(prominent ? .clear : theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func hintRow(symbol: String, text: String, shortcut: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSubtle)
                .frame(width: 12)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textMuted)

            Spacer()

            Text(shortcut)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
        }
    }
}
