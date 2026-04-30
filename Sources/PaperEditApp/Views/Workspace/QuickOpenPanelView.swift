import SwiftUI

struct QuickOpenPanelView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @FocusState private var queryFocused: Bool

    let theme: PaperTheme

    var body: some View {
        let items = workspaceStore.quickOpenItems()

        VStack(spacing: 0) {
            queryRow(items: items)
            errorMessage
            indexMessage

            ScrollView {
                if items.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            QuickOpenPanelRow(
                                item: item,
                                isSelected: index == workspaceStore.quickOpenModel.selectedIndex,
                                theme: theme
                            ) {
                                workspaceStore.openQuickOpenItem(item)
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .frame(maxHeight: 260)
        }
        .background {
            ZStack {
                VisualEffectBlur(material: .sidebar)
                theme.secondaryElevatedBackground.opacity(0.94)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .shadow(color: theme.shadow.opacity(0.18), radius: 14, y: 8)
        .onAppear {
            queryFocused = true
        }
        .onChange(of: workspaceStore.quickOpenModel.query) {
            workspaceStore.quickOpenModel.selectedIndex = 0
            workspaceStore.quickOpenErrorMessage = nil
        }
        .onMoveCommand { direction in
            switch direction {
            case .down:
                workspaceStore.quickOpenModel.moveSelection(delta: 1, itemCount: items.count)
            case .up:
                workspaceStore.quickOpenModel.moveSelection(delta: -1, itemCount: items.count)
            default:
                break
            }
        }
        .onExitCommand {
            workspaceStore.closeQuickOpen()
        }
    }

    private func queryRow(items: [QuickOpenItem]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textSubtle)

            TextField("Search files by name or path", text: Binding(
                get: { workspaceStore.quickOpenModel.query },
                set: { workspaceStore.quickOpenModel.query = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.textPrimary)
            .focused($queryFocused)
            .accessibilityLabel("Search files by name or path")
            .onSubmit {
                guard items.indices.contains(workspaceStore.quickOpenModel.selectedIndex) else { return }
                workspaceStore.openQuickOpenItem(items[workspaceStore.quickOpenModel.selectedIndex])
            }

            Button {
                workspaceStore.closeQuickOpen()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textSubtle)
                    .frame(width: 30, height: 30)
                    .background(theme.hover, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Quick Open")
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let message = workspaceStore.quickOpenErrorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))

                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
            }
            .foregroundStyle(theme.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(theme.warning.opacity(0.08))
        }
    }

    @ViewBuilder
    private var indexMessage: some View {
        if let message = workspaceStore.quickOpenIndexMessage {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10, weight: .semibold))

                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
            }
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.hover)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 21, weight: .light))
                .foregroundStyle(theme.textSubtle)

            Text("No matching files")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            Text("Try a filename, folder name, or partial path.")
                .font(.system(size: 11))
                .foregroundStyle(theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }
}

private struct QuickOpenPanelRow: View {
    let item: QuickOpenItem
    let isSelected: Bool
    let theme: PaperTheme
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: item.format.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? theme.accent : Color(hex: item.format.accentHex).opacity(0.88))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(minWidth: 0, alignment: .leading)

                Spacer(minLength: 8)

                Text(item.source.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.accent : theme.textSubtle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? theme.accent.opacity(0.14) : theme.hover)
                    )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? theme.selectedItemFill : hovering ? theme.hover : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? theme.selectedItemStroke : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.subtitle), \(item.source.label)")
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}
