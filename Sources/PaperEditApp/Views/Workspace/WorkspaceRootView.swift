import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceRootView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var settingsModel: SettingsWindowModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDropTargeted = false

    private var theme: PaperTheme {
        PaperTheme.resolve(from: workspaceStore.themeMode, colorScheme: colorScheme, accentSwatch: workspaceStore.accentSwatch)
    }

    private var isDarkTheme: Bool {
        switch workspaceStore.themeMode {
        case .dark:
            true
        case .light:
            false
        case .system:
            colorScheme == .dark
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompactWidth = geometry.size.width < 980
            let effectiveSidebarWidth = isCompactWidth ? min(workspaceStore.sidebarWidth, 220) : workspaceStore.sidebarWidth
            let titlebarTopInset = geometry.safeAreaInsets.top

            ZStack {
                theme.windowBackground
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        theme.chromeBackground.opacity(isDarkTheme ? 0.26 : 0.58),
                        theme.windowBackground.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    WorkspaceTitleBar(theme: theme, isCompactWidth: isCompactWidth, topInset: titlebarTopInset)

                    HStack(spacing: 0) {
                        if effectiveSidebarWidth > 0 {
                            WorkspaceSidebar(theme: theme)
                                .frame(width: effectiveSidebarWidth)

                            SidebarResizeHandle(theme: theme)
                        }

                        editorRegion(isCompactWidth: isCompactWidth)
                    }

                    WorkspaceStatusBar(theme: theme, status: workspaceStore.status)
                }
                .overlay(WindowConfigurator().allowsHitTesting(false))
                .overlay(alignment: .center) {
                    if workspaceStore.showCommandPalette {
                        CommandPaletteView(theme: theme)
                    } else if workspaceStore.showQuickOpen {
                        QuickOpenView(theme: theme)
                    }
                }
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                    for provider in providers {
                        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                            guard
                                let data,
                                let url = URL(dataRepresentation: data, relativeTo: nil)
                            else { return }
                            Task { @MainActor in
                                workspaceStore.openExternalFiles([url])
                            }
                        }
                    }
                    return true
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    @ViewBuilder
    private func editorRegion(isCompactWidth: Bool) -> some View {
        Group {
            if let tab = workspaceStore.activeTab {
                if tab.format == .markdown {
                    MarkdownPreviewContainer(
                        tab: tab,
                        theme: theme,
                        isDark: isDarkTheme,
                        viewMode: workspaceStore.viewMode,
                        isCompactWidth: isCompactWidth,
                        onTextChange: workspaceStore.updateText(_:selection:),
                        onSelectionChange: workspaceStore.updateSelection(_:)
                    )
                } else if tab.format.supportsStructuredPreview {
                    StructuredPreviewContainer(
                        tab: tab,
                        theme: theme,
                        isDark: isDarkTheme,
                        viewMode: workspaceStore.viewMode,
                        isCompactWidth: isCompactWidth,
                        onTextChange: workspaceStore.updateText(_:selection:),
                        onSelectionChange: workspaceStore.updateSelection(_:),
                        onToggleFold: tab.format == .json ? { _ in workspaceStore.togglePrimaryJSONFold() } : nil
                    )
                } else {
                    CodeEditorView(
                        text: tab.text,
                        language: tab.format,
                        selection: tab.selection,
                        showLineNumbers: true,
                        showsFolding: tab.showsFolding,
                        theme: theme,
                        isDark: isDarkTheme,
                        foldMarkers: tab.foldMarkers,
                        onTextChange: workspaceStore.updateText(_:selection:),
                        onSelectionChange: workspaceStore.updateSelection(_:)
                    ) { _ in
                        workspaceStore.togglePrimaryJSONFold()
                    }
                }
            } else {
                EmptyStateView(theme: theme, isDropTargeted: isDropTargeted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.canvasBackground)
        .clipped()
    }

    private var preferredColorScheme: ColorScheme? {
        switch workspaceStore.themeMode {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

private struct SidebarResizeHandle: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let theme: PaperTheme
    @State private var dragStartWidth: CGFloat?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(width: 8)
                .contentShape(Rectangle())

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(theme.borderStrong.opacity(0.72))
                .frame(width: 2, height: 44)
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = workspaceStore.sidebarWidth
                    }
                    workspaceStore.updateSidebarWidth((dragStartWidth ?? 240) + value.translation.width)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                }
        )
    }
}
