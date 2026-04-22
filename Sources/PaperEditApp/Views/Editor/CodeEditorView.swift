import AppKit
import SwiftUI

struct CodeEditorView: View {
    var text: String
    var language: EditorFileFormat
    var selection: NSRange
    var showLineNumbers: Bool
    var showsFolding: Bool
    var theme: PaperTheme
    var isDark: Bool
    var foldMarkers: [EditorFoldMarker]
    var onTextChange: (String, NSRange) -> Void
    var onSelectionChange: (NSRange) -> Void
    var onToggleFold: ((Int) -> Void)?

    var body: some View {
        NativeCodeTextView(
            text: text,
            language: language,
            selection: selection,
            showLineNumbers: showLineNumbers,
            theme: theme,
            isDark: isDark,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.editorBackground)
    }
}

private struct NativeCodeTextView: NSViewRepresentable {
    var text: String
    var language: EditorFileFormat
    var selection: NSRange
    var showLineNumbers: Bool
    var theme: PaperTheme
    var isDark: Bool
    var onTextChange: (String, NSRange) -> Void
    var onSelectionChange: (NSRange) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> EditorTextContainerView {
        let view = EditorTextContainerView(showLineNumbers: showLineNumbers)
        view.textView.delegate = context.coordinator
        context.coordinator.containerView = view
        context.coordinator.applyExternalUpdate = true
        view.update(text: text, selection: selection, language: language, showLineNumbers: showLineNumbers, theme: theme, isDark: isDark)
        context.coordinator.applyExternalUpdate = false
        return view
    }

    func updateNSView(_ nsView: EditorTextContainerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.containerView = nsView
        context.coordinator.applyExternalUpdate = true
        nsView.update(text: text, selection: selection, language: language, showLineNumbers: showLineNumbers, theme: theme, isDark: isDark)
        context.coordinator.applyExternalUpdate = false
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeCodeTextView
        weak var containerView: EditorTextContainerView?
        var applyExternalUpdate = false

        init(parent: NativeCodeTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !applyExternalUpdate, let textView = notification.object as? NSTextView else { return }
            containerView?.refreshLineNumbers()
            containerView?.rehighlight(language: parent.language, theme: parent.theme, isDark: parent.isDark)
            parent.onTextChange(textView.string, textView.selectedRange())
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !applyExternalUpdate, let textView = notification.object as? NSTextView else { return }
            parent.onSelectionChange(textView.selectedRange())
        }
    }
}

private final class EditorTextContainerView: NSView {
    let textView = NSTextView()

    private let gutterScrollView = NSScrollView()
    private let gutterTextView = NSTextView()
    private let editorScrollView = NSScrollView()
    private let stackView = NSStackView()
    private let gutterWidthConstraint: NSLayoutConstraint

    private var currentTheme: PaperTheme?
    private var currentLanguage: EditorFileFormat = .plainText
    private var currentIsDark = false

    init(showLineNumbers: Bool) {
        gutterWidthConstraint = gutterScrollView.widthAnchor.constraint(equalToConstant: showLineNumbers ? 48 : 0)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        configureGutter()
        configureEditor()
        configureLayout()
        gutterWidthConstraint.isActive = true
        syncScrollOffsets()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func update(
        text: String,
        selection: NSRange,
        language: EditorFileFormat,
        showLineNumbers: Bool,
        theme: PaperTheme,
        isDark: Bool
    ) {
        currentLanguage = language
        currentTheme = theme
        currentIsDark = isDark

        let editorBackground = NSColor(theme.editorBackground)
        let gutterBackground = NSColor(theme.editorBackground)
        layer?.backgroundColor = editorBackground.cgColor
        editorScrollView.backgroundColor = editorBackground
        textView.backgroundColor = editorBackground
        gutterScrollView.backgroundColor = gutterBackground
        gutterTextView.backgroundColor = gutterBackground

        gutterWidthConstraint.constant = showLineNumbers ? 48 : 0
        gutterScrollView.isHidden = !showLineNumbers

        let needsHighlightRefresh = textView.string != text
            || currentLanguage != language
            || currentIsDark != isDark

        if needsHighlightRefresh {
            let highlighted = SyntaxHighlighter.highlightedText(
                for: text,
                language: language,
                theme: theme,
                isDark: isDark
            )
            textView.textStorage?.setAttributedString(highlighted)
            textView.typingAttributes = SyntaxHighlighter.baseAttributes(theme: theme)
            refreshLineNumbers()
        } else if textView.typingAttributes[.foregroundColor] == nil {
            textView.typingAttributes = SyntaxHighlighter.baseAttributes(theme: theme)
        }

        if textView.selectedRange() != selection {
            textView.setSelectedRange(selection)
            textView.scrollRangeToVisible(selection)
        }
    }

    func refreshLineNumbers() {
        let lineCount = max(1, textView.string.components(separatedBy: "\n").count)
        let lineNumbers = (1...lineCount).map(String.init).joined(separator: "\n")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        gutterTextView.textStorage?.setAttributedString(
            NSAttributedString(
                string: lineNumbers,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor(currentTheme?.textSubtle ?? Color(nsColor: .secondaryLabelColor)),
                    .paragraphStyle: paragraphStyle,
                ]
            )
        )
    }

    func rehighlight(language: EditorFileFormat, theme: PaperTheme, isDark: Bool) {
        currentLanguage = language
        currentTheme = theme
        currentIsDark = isDark
        let selection = textView.selectedRange()
        let highlighted = SyntaxHighlighter.highlightedText(
            for: textView.string,
            language: language,
            theme: theme,
            isDark: isDark
        )
        textView.textStorage?.setAttributedString(highlighted)
        textView.typingAttributes = SyntaxHighlighter.baseAttributes(theme: theme)
        textView.setSelectedRange(selection)
    }

    private func configureLayout() {
        stackView.orientation = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        stackView.addArrangedSubview(gutterScrollView)
        stackView.addArrangedSubview(editorScrollView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func configureEditor() {
        let textContainer = NSTextContainer(size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        textView.textContainer = textContainer
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 16)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true

        editorScrollView.drawsBackground = true
        editorScrollView.hasVerticalScroller = true
        editorScrollView.hasHorizontalScroller = true
        editorScrollView.borderType = .noBorder
        editorScrollView.documentView = textView
        editorScrollView.contentView.postsBoundsChangedNotifications = true
    }

    private func configureGutter() {
        let gutterContainer = NSTextContainer(size: NSSize(width: 48, height: CGFloat.greatestFiniteMagnitude))
        gutterContainer.widthTracksTextView = true
        gutterTextView.textContainer = gutterContainer
        gutterTextView.isEditable = false
        gutterTextView.isSelectable = false
        gutterTextView.drawsBackground = true
        gutterTextView.textContainerInset = NSSize(width: 0, height: 16)
        gutterTextView.textContainer?.lineFragmentPadding = 0
        gutterTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)

        gutterScrollView.drawsBackground = true
        gutterScrollView.hasVerticalScroller = false
        gutterScrollView.hasHorizontalScroller = false
        gutterScrollView.borderType = .noBorder
        gutterScrollView.documentView = gutterTextView

        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        gutterScrollView.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.trailingAnchor.constraint(equalTo: gutterScrollView.trailingAnchor),
            divider.topAnchor.constraint(equalTo: gutterScrollView.topAnchor),
            divider.bottomAnchor.constraint(equalTo: gutterScrollView.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
        ])
    }

    private func syncScrollOffsets() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: editorScrollView.contentView
        )
    }

    @objc private func editorDidScroll(_ notification: Notification) {
        let origin = editorScrollView.contentView.bounds.origin
        gutterScrollView.contentView.scroll(to: NSPoint(x: 0, y: origin.y))
        gutterScrollView.reflectScrolledClipView(gutterScrollView.contentView)
    }
}

private enum SyntaxHighlighter {
    private static let shellKeywords: Set<String> = [
        "alias", "break", "case", "continue", "do", "done", "elif", "else", "esac",
        "eval", "exit", "export", "fi", "for", "function", "if", "in", "local", "readonly",
        "return", "select", "shift", "source", "test", "then", "trap", "unalias", "unset",
        "until", "while",
    ]

    static func highlightedText(
        for text: String,
        language: EditorFileFormat,
        theme: PaperTheme,
        isDark: Bool
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes(theme: theme))

        guard language == .shellScript else {
            return attributed
        }

        highlightShell(in: attributed, theme: theme, isDark: isDark)
        return attributed
    }

    static func baseAttributes(theme: PaperTheme) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor(theme.textPrimary),
        ]
    }

    private static func highlightShell(
        in attributed: NSMutableAttributedString,
        theme: PaperTheme,
        isDark: Bool
    ) {
        let string = attributed.string
        let nsString = string as NSString
        let keywordColor = NSColor(isDark ? Color(hex: "#FF9F7A") : Color(hex: "#B42318"))
        let stringColor = NSColor(isDark ? Color(hex: "#A8E6A3") : Color(hex: "#1F7A2F"))
        let commentColor = NSColor(theme.textSubtle)
        let variableColor = NSColor(isDark ? Color(hex: "#7DD3FC") : Color(hex: "#005A9C"))
        let shebangColor = NSColor(isDark ? Color(hex: "#C4B5FD") : Color(hex: "#6D28D9"))

        string.enumerateSubstrings(in: string.startIndex..<string.endIndex, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let nsRange = NSRange(lineRange, in: string)
            highlightShellLine(
                in: attributed,
                fullText: nsString,
                lineRange: nsRange,
                keywordColor: keywordColor,
                stringColor: stringColor,
                commentColor: commentColor,
                variableColor: variableColor,
                shebangColor: shebangColor
            )
        }
    }

    private static func highlightShellLine(
        in attributed: NSMutableAttributedString,
        fullText: NSString,
        lineRange: NSRange,
        keywordColor: NSColor,
        stringColor: NSColor,
        commentColor: NSColor,
        variableColor: NSColor,
        shebangColor: NSColor
    ) {
        guard lineRange.location != NSNotFound else { return }
        let line = fullText.substring(with: lineRange)
        let chars = Array(line)

        if line.hasPrefix("#!") {
            attributed.addAttribute(.foregroundColor, value: shebangColor, range: lineRange)
            return
        }

        var index = 0
        while index < chars.count {
            let char = chars[index]

            if char == "#" {
                let commentRange = NSRange(location: lineRange.location + index, length: chars.count - index)
                attributed.addAttribute(.foregroundColor, value: commentColor, range: commentRange)
                break
            }

            if char == "\"" || char == "'" {
                let start = index
                let quote = char
                index += 1
                while index < chars.count {
                    if chars[index] == quote {
                        index += 1
                        break
                    }
                    if quote == "\"", chars[index] == "\\", index + 1 < chars.count {
                        index += 2
                    } else {
                        index += 1
                    }
                }
                let range = NSRange(location: lineRange.location + start, length: max(1, index - start))
                attributed.addAttribute(.foregroundColor, value: stringColor, range: range)
                continue
            }

            if char == "$" {
                let start = index
                index += 1

                if index < chars.count, chars[index] == "{" {
                    index += 1
                    while index < chars.count, chars[index] != "}" {
                        index += 1
                    }
                    if index < chars.count { index += 1 }
                } else if index < chars.count, chars[index] == "(" {
                    var depth = 1
                    index += 1
                    while index < chars.count, depth > 0 {
                        if chars[index] == "(" { depth += 1 }
                        if chars[index] == ")" { depth -= 1 }
                        index += 1
                    }
                } else {
                    while index < chars.count, chars[index].isLetter || chars[index].isNumber || chars[index] == "_" || chars[index] == "@" || chars[index] == "?" {
                        index += 1
                    }
                }

                let range = NSRange(location: lineRange.location + start, length: max(1, index - start))
                attributed.addAttribute(.foregroundColor, value: variableColor, range: range)
                continue
            }

            if char.isLetter || char == "_" {
                let start = index
                index += 1
                while index < chars.count, chars[index].isLetter || chars[index].isNumber || chars[index] == "_" {
                    index += 1
                }

                let token = String(chars[start..<index])
                if shellKeywords.contains(token) {
                    let range = NSRange(location: lineRange.location + start, length: token.count)
                    attributed.addAttribute(.foregroundColor, value: keywordColor, range: range)
                    attributed.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold), range: range)
                }
                continue
            }

            index += 1
        }
    }
}
