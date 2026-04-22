import SwiftUI

struct QuickOpenView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @FocusState private var queryFocused: Bool

    let theme: PaperTheme

    var body: some View {
        let items = workspaceStore.quickOpenItems()

        GeometryReader { proxy in
            let panelWidth = min(620, max(320, proxy.size.width - 48))

            ZStack(alignment: .top) {
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                    .onTapGesture {
                        workspaceStore.closeQuickOpen()
                    }

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(theme.textMuted)

                        TextField("Quick open files...", text: Binding(
                            get: { workspaceStore.quickOpenModel.query },
                            set: { workspaceStore.quickOpenModel.query = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .focused($queryFocused)
                        .onSubmit {
                            guard items.indices.contains(workspaceStore.quickOpenModel.selectedIndex) else { return }
                            workspaceStore.openQuickOpenItem(items[workspaceStore.quickOpenModel.selectedIndex])
                        }

                        Text("⌘P")
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
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundStyle(theme.textSubtle)

                                Text("No matching files")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)

                                Text("Try a different filename or open a folder first.")
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
                                    QuickOpenRow(
                                        item: item,
                                        isSelected: index == workspaceStore.quickOpenModel.selectedIndex,
                                        theme: theme
                                    ) {
                                        workspaceStore.openQuickOpenItem(item)
                                    }
                                }
                            }
                            .padding(10)
                        }
                    }
                    .frame(maxHeight: 360)
                }
                .frame(width: panelWidth)
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
        .onChange(of: workspaceStore.quickOpenModel.query) {
            workspaceStore.quickOpenModel.selectedIndex = 0
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
}

private struct QuickOpenRow: View {
    let item: QuickOpenItem
    let isSelected: Bool
    let theme: PaperTheme
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.format.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? theme.accentForeground : Color(hex: item.format.accentHex).opacity(0.88))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? theme.accentForeground : theme.textPrimary)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? theme.accentForeground.opacity(0.82) : theme.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text(item.source.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.accentForeground.opacity(0.88) : theme.textSubtle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? theme.accentForeground.opacity(0.14) : theme.hover)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
    }
}
