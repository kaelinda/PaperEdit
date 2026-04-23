import Foundation
import SwiftUI

struct MarkdownPreviewContainer: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    let tab: EditorTab
    let theme: PaperTheme
    let isDark: Bool
    let viewMode: EditorViewMode
    let isCompactWidth: Bool
    let onTextChange: (String, NSRange) -> Void
    let onSelectionChange: (NSRange) -> Void
    @State private var compactSplitShowsPreview = false

    private var markdownBlocks: [MarkdownPreviewBlock] {
        MarkdownPreviewParser.parse(tab.text)
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
        EditorPaneSurface(theme: theme, isDark: isDark) {
            CodeEditorView(
                text: tab.text,
                language: .markdown,
                selection: tab.selection,
                fontSize: workspaceStore.editorFontSize,
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
        .padding(.horizontal, isCompactWidth ? 14 : 18)
        .padding(.vertical, isCompactWidth ? 14 : 18)
        .background(theme.canvasBackground)
    }

    private var markdownPreview: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(tab.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textSubtle)

                    MarkdownRenderedDocument(blocks: markdownBlocks, theme: theme, isDark: isDark)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 52)
                .padding(.vertical, 44)
                .frame(maxWidth: 760, alignment: .leading)
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
            .padding(.horizontal, isCompactWidth ? 20 : 40)
            .padding(.vertical, isCompactWidth ? 20 : 32)
            .frame(maxWidth: .infinity)
        }
        .background(theme.canvasBackground)
    }
}

private struct MarkdownRenderedDocument: View {
    let blocks: [MarkdownPreviewBlock]
    let theme: PaperTheme
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownPreviewBlock) -> some View {
        switch block {
        case let .heading(level, text):
            inlineText(text)
                .font(headingFont(for: level))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level == 1 ? 2 : 10)

        case let .paragraph(text):
            inlineText(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)

        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    listRow(marker: "•", text: item)
                }
            }

        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    listRow(marker: "\(index + 1).", text: item)
                }
            }

        case let .quote(text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(theme.accent.opacity(isDark ? 0.72 : 0.52))
                    .frame(width: 3)

                inlineText(text)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textMuted)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

        case let .code(language, text):
            VStack(alignment: .leading, spacing: 10) {
                if let language {
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textSubtle)
                        .tracking(0.8)
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    Text(text.isEmpty ? " " : text)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(theme.secondaryElevatedBackground.opacity(isDark ? 0.82 : 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
            }

        case .divider:
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
                .padding(.vertical, 6)
        }
    }

    private func listRow(marker: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 11) {
            Text(marker)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.textSubtle)
                .frame(width: 24, alignment: .trailing)

            inlineText(text)
                .font(.system(size: 15))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            .system(size: 30, weight: .bold)
        case 2:
            .system(size: 24, weight: .semibold)
        case 3:
            .system(size: 19, weight: .semibold)
        default:
            .system(size: 16, weight: .semibold)
        }
    }

    private func inlineText(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let attributed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        return Text(attributed)
    }
}

private enum MarkdownPreviewBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([String])
    case quote(String)
    case code(language: String?, text: String)
    case divider
}

private enum MarkdownPreviewParser {
    static func parse(_ text: String) -> [MarkdownPreviewBlock] {
        var blocks: [MarkdownPreviewBlock] = []
        var paragraphLines: [String] = []
        var unorderedItems: [String] = []
        var orderedItems: [String] = []
        var quoteLines: [String] = []
        var codeLines: [String] = []
        var codeLanguage: String?
        var isInCodeBlock = false

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
            paragraphLines.removeAll()
        }

        func flushUnorderedList() {
            guard !unorderedItems.isEmpty else { return }
            blocks.append(.unorderedList(unorderedItems))
            unorderedItems.removeAll()
        }

        func flushOrderedList() {
            guard !orderedItems.isEmpty else { return }
            blocks.append(.orderedList(orderedItems))
            orderedItems.removeAll()
        }

        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            blocks.append(.quote(quoteLines.joined(separator: "\n")))
            quoteLines.removeAll()
        }

        func flushOpenBlocks() {
            flushParagraph()
            flushUnorderedList()
            flushOrderedList()
            flushQuote()
        }

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isInCodeBlock {
                if trimmed.hasPrefix("```") {
                    blocks.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    codeLanguage = nil
                    isInCodeBlock = false
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if trimmed.hasPrefix("```") {
                flushOpenBlocks()
                isInCodeBlock = true
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                codeLanguage = language.isEmpty ? nil : language
                continue
            }

            if trimmed.isEmpty {
                flushOpenBlocks()
                continue
            }

            if isDivider(trimmed) {
                flushOpenBlocks()
                blocks.append(.divider)
                continue
            }

            if let heading = parseHeading(line) {
                flushOpenBlocks()
                blocks.append(.heading(level: heading.level, text: heading.text))
                continue
            }

            if let item = parseUnorderedListItem(line) {
                flushParagraph()
                flushOrderedList()
                flushQuote()
                unorderedItems.append(item)
                continue
            }

            if let item = parseOrderedListItem(line) {
                flushParagraph()
                flushUnorderedList()
                flushQuote()
                orderedItems.append(item)
                continue
            }

            if let quote = parseQuote(line) {
                flushParagraph()
                flushUnorderedList()
                flushOrderedList()
                quoteLines.append(quote)
                continue
            }

            flushUnorderedList()
            flushOrderedList()
            flushQuote()
            paragraphLines.append(line)
        }

        if isInCodeBlock {
            blocks.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
        }
        flushOpenBlocks()

        if blocks.isEmpty {
            return [.paragraph("Nothing to preview yet.")]
        }
        return blocks
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let level = trimmed.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else { return nil }
        let remainder = trimmed.dropFirst(level)
        guard remainder.first == " " else { return nil }
        return (level, String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces))
    }

    private static func parseUnorderedListItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
            return String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func parseOrderedListItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let number = trimmed[..<dotIndex]
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { return nil }
        let afterDot = trimmed[trimmed.index(after: dotIndex)...]
        guard afterDot.first == " " else { return nil }
        return String(afterDot.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func parseQuote(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return nil }
        return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func isDivider(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        let characters = Set(trimmed)
        return characters == ["-"] || characters == ["*"] || characters == ["_"]
    }
}
