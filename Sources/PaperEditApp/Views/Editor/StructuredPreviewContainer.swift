import Foundation
import SwiftUI

struct StructuredPreviewContainer: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let tab: EditorTab
    let theme: PaperTheme
    let isDark: Bool
    let viewMode: EditorViewMode
    let isCompactWidth: Bool
    let onTextChange: (String, NSRange) -> Void
    let onSelectionChange: (NSRange) -> Void
    let onToggleFold: ((Int) -> Void)?
    @State private var compactSplitShowsPreview = false

    private var previewDocument: StructuredPreviewDocument {
        StructuredPreviewBuilder.build(format: tab.format, text: tab.text)
    }

    var body: some View {
        let document = previewDocument

        switch viewMode {
        case .edit:
            editorPane(document: document)
        case .split:
            if isCompactWidth {
                VStack(spacing: 0) {
                    compactSplitSwitcher

                    if compactSplitShowsPreview {
                        structuredPreview(document: document)
                    } else {
                        editorPane(document: document)
                    }
                }
            } else {
                HSplitView {
                    editorPane(document: document)
                        .frame(minWidth: 360)

                    structuredPreview(document: document)
                        .frame(minWidth: 360)
                }
            }
        case .wysiwyg:
            VStack(alignment: .leading, spacing: 0) {
                previewHeader
                structuredPreview(document: document)
            }
        }
    }

    private var compactSplitSwitcher: some View {
        HStack(spacing: 8) {
            Button {
                compactSplitShowsPreview = false
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(compactSplitShowsPreview ? theme.textMuted : theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(compactSplitShowsPreview ? .clear : theme.elevatedBackground)
                    )
            }
            .buttonStyle(.plain)

            Button {
                compactSplitShowsPreview = true
            } label: {
                Label("Preview", systemImage: "list.bullet.rectangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(compactSplitShowsPreview ? theme.textPrimary : theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(compactSplitShowsPreview ? theme.elevatedBackground : .clear)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(theme.windowBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }

    private func editorPane(document: StructuredPreviewDocument) -> some View {
        EditorPaneSurface(theme: theme, isDark: isDark) {
            VStack(spacing: 0) {
                if !document.diagnostics.isEmpty {
                    validationBanner(document: document)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                }

                CodeEditorView(
                    text: tab.text,
                    language: tab.format,
                    selection: tab.selection,
                    fontSize: workspaceStore.editorFontSize,
                    showLineNumbers: true,
                    showsFolding: tab.showsFolding,
                    theme: theme,
                    isDark: isDark,
                    foldMarkers: tab.foldMarkers,
                    onTextChange: onTextChange,
                    onSelectionChange: onSelectionChange,
                    onToggleFold: onToggleFold
                )
            }
        }
        .padding(.horizontal, isCompactWidth ? 14 : 18)
        .padding(.vertical, isCompactWidth ? 14 : 18)
        .background(theme.canvasBackground)
    }

    private func structuredPreview(document: StructuredPreviewDocument) -> some View {
        return ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    previewSummary(document)

                    if !document.diagnostics.isEmpty {
                        diagnosticsList(document.diagnostics)
                    }

                    if document.nodes.isEmpty {
                        EmptyStructuredPreview(theme: theme)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(document.nodes) { node in
                                StructuredPreviewNodeRow(node: node, depth: 0, theme: theme)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: 780, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(theme.editorBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
                .shadow(color: theme.shadow.opacity(isDark ? 0.28 : 0.14), radius: 28, y: 18)
            }
            .padding(.horizontal, isCompactWidth ? 20 : 32)
            .padding(.vertical, isCompactWidth ? 20 : 28)
            .frame(maxWidth: .infinity)
        }
        .background(theme.canvasBackground)
    }

    private func validationBanner(document: StructuredPreviewDocument) -> some View {
        let remainingCount = max(0, document.diagnostics.count - 1)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#B86B00"))

                Text("\(tab.format.displayName) validation")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Text("\(document.diagnostics.count) issue\(document.diagnostics.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSubtle)

                Spacer(minLength: 0)
            }

            Text(document.diagnostics[0])
                .font(.system(size: 12))
                .foregroundStyle(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            if remainingCount > 0 {
                Text("And \(remainingCount) more validation message\(remainingCount == 1 ? "" : "s") in preview.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSubtle)
            }
        }
        .padding(12)
        .background(Color(hex: "#FFCC00").opacity(isDark ? 0.12 : 0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: "#B86B00").opacity(0.25), lineWidth: 1)
        )
    }

    private var previewHeader: some View {
        HStack(spacing: 10) {
            Label("Structured Preview", systemImage: "list.bullet.rectangle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textMuted)
            Spacer()
            Text(tab.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSubtle)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(theme.windowBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }

    private func previewSummary(_ document: StructuredPreviewDocument) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tab.format.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: tab.format.accentHex))
                .frame(width: 34, height: 34)
                .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(document.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textSubtle)
            }

            Spacer(minLength: 0)
        }
    }

    private func diagnosticsList(_ diagnostics: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(diagnostics, id: \.self) { message in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#B86B00"))
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "#FFCC00").opacity(isDark ? 0.12 : 0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: "#B86B00").opacity(0.25), lineWidth: 1)
        )
    }
}

private struct StructuredPreviewNodeRow: View {
    let node: StructuredPreviewNode
    let depth: Int
    let theme: PaperTheme
    @State private var isExpanded = true

    private let expansionAnimation = Animation.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.12)

    private var hasChildren: Bool {
        !node.children.isEmpty
    }

    private func toggleExpansion() {
        guard hasChildren else { return }
        withAnimation(expansionAnimation) {
            isExpanded.toggle()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    toggleExpansion()
                } label: {
                    Image(systemName: hasChildren ? "chevron.right" : "circle.fill")
                        .font(.system(size: hasChildren ? 10 : 4, weight: .bold))
                        .rotationEffect(.degrees(isExpanded && hasChildren ? 90 : 0))
                        .frame(width: 14, height: 14)
                        .foregroundStyle(hasChildren ? theme.textSubtle : theme.border)
                }
                .buttonStyle(.plain)
                .disabled(!hasChildren)

                Image(systemName: node.kind.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 16)

                Text(node.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let value = node.value {
                    Text(value)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.textMuted)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .padding(.leading, CGFloat(depth) * 18)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(depth == 0 ? theme.secondaryElevatedBackground : theme.hover.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(depth == 0 ? theme.border : .clear, lineWidth: 1)
            )
            .onTapGesture {
                toggleExpansion()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(hasChildren ? .isButton : [])
            .accessibilityValue(hasChildren ? (isExpanded ? "Expanded" : "Collapsed") : "")
            .animation(expansionAnimation, value: isExpanded)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(node.children) { child in
                        StructuredPreviewNodeRow(node: child, depth: depth + 1, theme: theme)
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
                    )
                )
            }
        }
    }

    private var iconColor: Color {
        switch node.kind {
        case .root, .section:
            theme.accent
        case .object, .array, .element:
            Color(hex: "#248A3D")
        case .attribute, .property:
            Color(hex: "#B86B00")
        case .item, .value:
            theme.textSubtle
        }
    }
}

private struct EmptyStructuredPreview: View {
    let theme: PaperTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No previewable structure", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            Text("Fix parse errors or add structured content to populate this preview.")
                .font(.system(size: 12))
                .foregroundStyle(theme.textSubtle)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.secondaryElevatedBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}
