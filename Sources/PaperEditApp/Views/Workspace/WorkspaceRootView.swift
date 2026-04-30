import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceRootView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var settingsModel: SettingsWindowModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            let sidebarReferenceWidth: CGFloat = isCompactWidth ? 220 : 240
            let sidebarRevealProgress = min(1, max(0, effectiveSidebarWidth / sidebarReferenceWidth))
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
                        ZStack(alignment: .leading) {
                            WorkspaceSidebar(theme: theme)
                                .frame(width: sidebarReferenceWidth)
                                .opacity(sidebarRevealProgress)
                                .offset(x: -18 * (1 - sidebarRevealProgress))
                        }
                        .frame(width: effectiveSidebarWidth, alignment: .leading)
                        .shadow(color: theme.shadow.opacity(0.08 * sidebarRevealProgress), radius: 14, x: 3, y: 0)
                        .contentShape(Rectangle())
                        .allowsHitTesting(sidebarRevealProgress > 0.96)
                        .clipped()

                        SidebarResizeHandle(theme: theme)
                            .frame(width: max(0, 14 * sidebarRevealProgress))
                            .opacity(sidebarRevealProgress)
                            .clipped()
                            .allowsHitTesting(sidebarRevealProgress > 0.98)

                        editorRegion(isCompactWidth: isCompactWidth)
                    }
                    .animation(sidebarAnimation, value: effectiveSidebarWidth)

                    WorkspaceStatusBar(theme: theme, status: workspaceStore.status)
                }
                .overlay(WindowConfigurator().allowsHitTesting(false))
                .overlay(alignment: .center) {
                    if workspaceStore.showCommandPalette {
                        CommandPaletteView(theme: theme)
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
                    EditorPaneSurface(theme: theme, isDark: isDarkTheme) {
                        CodeEditorView(
                            text: tab.text,
                            language: tab.format,
                            selection: tab.selection,
                            fontSize: workspaceStore.editorFontSize,
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
                    .padding(18)
                    .background(theme.canvasBackground)
                }
            } else {
                EmptyStateView(theme: theme, isDropTargeted: isDropTargeted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.canvasBackground)
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let state = workspaceStore.activeTab?.conflictState, state.isBlockingSave {
                    conflictBanner(state)
                }
                if let message = workspaceStore.recoveryMessage {
                    recoveryBanner(message)
                }
                if let message = workspaceStore.openFailureMessage {
                    noticeBanner(message)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 18)
        }
        .clipped()
    }

    private func conflictBanner(_ state: FileConflictState) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(state.message)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            Button("Keep Local") {
                workspaceStore.keepLocalVersionForActiveTab()
            }
            .buttonStyle(.borderedProminent)

            Button("Reload") {
                reloadActiveTabAfterConfirmation()
            }
            .buttonStyle(.bordered)

            Button("Save Anyway") {
                _ = workspaceStore.saveActiveTabIgnoringConflict()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.warning.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: theme.shadow.opacity(0.12), radius: 16, y: 8)
    }

    private func recoveryBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(theme.accent)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
            Spacer()
            Button("Restore") {
                workspaceStore.recoverPendingDrafts()
            }
            .buttonStyle(.borderedProminent)
            Button("Discard") {
                workspaceStore.discardPendingDrafts()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private func noticeBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(theme.warning)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private func reloadActiveTabAfterConfirmation() {
        guard workspaceStore.activeTab?.isDirty == true else {
            workspaceStore.reloadActiveTabFromDisk()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reload from Disk?"
        alert.informativeText = "Reloading replaces your local unsaved edits with the current file on disk."
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        workspaceStore.reloadActiveTabFromDisk()
    }

    private var preferredColorScheme: ColorScheme? {
        switch workspaceStore.themeMode {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    private var sidebarAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.34, dampingFraction: 0.88, blendDuration: 0.08)
    }
}

private struct SidebarResizeHandle: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let theme: PaperTheme
    @State private var dragStartWidth: CGFloat?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(width: 14)
                .contentShape(Rectangle())

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(focused ? theme.accent : theme.borderStrong.opacity(0.72))
                .frame(width: focused ? 3 : 2, height: 44)
        }
        .frame(width: 14)
        .focusable()
        .focused($focused)
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
        .onMoveCommand { direction in
            guard focused else { return }
            switch direction {
            case .left:
                adjustSidebarWidth(by: -20)
            case .right:
                adjustSidebarWidth(by: 20)
            default:
                break
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sidebar Width")
        .accessibilityValue(sidebarAccessibilityValue)
        .accessibilityHint("Drag, or use the left and right arrow keys, to resize the sidebar.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustSidebarWidth(by: 20)
            case .decrement:
                adjustSidebarWidth(by: -20)
            default:
                break
            }
        }
        .animation(.easeOut(duration: 0.12), value: focused)
    }

    private var sidebarAccessibilityValue: String {
        workspaceStore.sidebarWidth == 0 ? "Collapsed" : "\(Int(workspaceStore.sidebarWidth)) points"
    }

    private func adjustSidebarWidth(by delta: CGFloat) {
        let baseWidth = workspaceStore.sidebarWidth == 0 ? WorkspaceStore.defaultSidebarWidth : workspaceStore.sidebarWidth
        workspaceStore.updateSidebarWidth(baseWidth + delta)
    }
}
