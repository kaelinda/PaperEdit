import SwiftUI

struct CommandPaletteView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var settingsModel: SettingsWindowModel
    @FocusState private var queryFocused: Bool

    let theme: PaperTheme

    var body: some View {
        let items = workspaceStore.filteredCommands()

        GeometryReader { proxy in
            let paletteWidth = min(560, max(280, proxy.size.width - 48))
            let isCompact = paletteWidth < 460

            ZStack(alignment: .top) {
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                    .onTapGesture {
                        workspaceStore.closeCommandPalette()
                    }

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(theme.textMuted)

                        TextField("Search commands or files...", text: Binding(
                            get: { workspaceStore.commandPaletteModel.query },
                            set: { workspaceStore.commandPaletteModel.query = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .focused($queryFocused)
                        .onSubmit {
                            guard items.indices.contains(workspaceStore.commandPaletteModel.selectedIndex) else { return }
                            workspaceStore.executeCommand(items[workspaceStore.commandPaletteModel.selectedIndex], settingsModel: settingsModel)
                        }

                        Text("⌘⇧P")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.textSubtle)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(theme.secondaryElevatedBackground.opacity(0.92))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.border)
                            .frame(height: 1)
                    }

                    ScrollView {
                        if items.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundStyle(theme.textSubtle)

                                Text("No commands found")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)

                                Text("Try a different search or press Esc to close.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 42)
                            .padding(.horizontal, 20)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    CommandPaletteRow(
                                        item: item,
                                        isSelected: index == workspaceStore.commandPaletteModel.selectedIndex,
                                        showsCategory: !isCompact,
                                        theme: theme
                                    ) {
                                        workspaceStore.executeCommand(item, settingsModel: settingsModel)
                                    }
                                }
                            }
                            .padding(10)
                        }
                    }
                    .frame(maxHeight: 318)
                }
                .frame(width: paletteWidth)
                .background {
                    ZStack {
                        VisualEffectBlur(material: .hudWindow)
                        theme.chromeBackground.opacity(0.82)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                        .blendMode(.screen)
                }
                .shadow(color: theme.shadow.opacity(0.36), radius: 28, y: 16)
                .padding(.top, proxy.size.height * 0.18)
            }
        }
        .onAppear {
            queryFocused = true
        }
        .onChange(of: workspaceStore.commandPaletteModel.query) {
            workspaceStore.commandPaletteModel.selectedIndex = 0
        }
        .onMoveCommand { direction in
            switch direction {
            case .down:
                workspaceStore.commandPaletteModel.moveSelection(delta: 1, itemCount: items.count)
            case .up:
                workspaceStore.commandPaletteModel.moveSelection(delta: -1, itemCount: items.count)
            default:
                break
            }
        }
        .onExitCommand {
            workspaceStore.closeCommandPalette()
        }
    }
}

private struct CommandPaletteRow: View {
    let item: CommandItem
    let isSelected: Bool
    let showsCategory: Bool
    let theme: PaperTheme
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? theme.accentForeground : theme.textMuted)
                    .frame(width: 18)

                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? theme.accentForeground : theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 10)

                if showsCategory {
                    Text(item.category)
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? theme.accentForeground.opacity(0.82) : theme.textMuted)
                }

                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? theme.accentForeground.opacity(0.92) : theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? theme.accentForeground.opacity(0.14) : theme.hover)
                        )
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? theme.selectedItemFill : hovering ? theme.hover : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? theme.selectedItemStroke : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
