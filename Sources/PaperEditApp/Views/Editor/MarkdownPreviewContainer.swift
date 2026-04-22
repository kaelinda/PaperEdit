import Foundation
import SwiftUI

struct MarkdownPreviewContainer: View {
    let tab: EditorTab
    let theme: PaperTheme
    let isDark: Bool
    let viewMode: EditorViewMode
    let isCompactWidth: Bool
    let onTextChange: (String, NSRange) -> Void
    let onSelectionChange: (NSRange) -> Void
    @State private var compactSplitShowsPreview = false

    private var renderedMarkdown: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        return (try? AttributedString(markdown: tab.text, options: options)) ?? AttributedString(tab.text)
    }

    var body: some View {
        switch viewMode {
        case .edit:
            editorPane
        case .split:
            if isCompactWidth {
                VStack(spacing: 0) {
                    compactSplitSwitcher

                    if compactSplitShowsPreview {
                        markdownPreview
                    } else {
                        editorPane
                    }
                }
            } else {
                HSplitView {
                    editorPane
                        .frame(minWidth: 360)

                    markdownPreview
                        .frame(minWidth: 360)
                }
            }
        case .wysiwyg:
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Label("Composed Markdown", systemImage: "eye")
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

                markdownPreview
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
                Label("Preview", systemImage: "eye")
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

    private var editorPane: some View {
        CodeEditorView(
            text: tab.text,
            language: .markdown,
            selection: tab.selection,
            showLineNumbers: true,
            showsFolding: false,
            theme: theme,
            isDark: isDark,
            foldMarkers: [],
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onToggleFold: nil
        )
    }

    private var markdownPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(renderedMarkdown)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(5)
                    .textSelection(.enabled)
            }
            .padding(40)
            .frame(maxWidth: 650, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(theme.windowBackground)
    }
}
