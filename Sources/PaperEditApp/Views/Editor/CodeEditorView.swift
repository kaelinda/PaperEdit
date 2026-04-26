import AppKit
import SwiftUI

struct CodeEditorView: View {
    var text: String
    var language: EditorFileFormat
    var selection: NSRange
    var fontSize: CGFloat
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
            fontSize: fontSize,
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

struct EditorPaneSurface<Content: View>: View {
    let theme: PaperTheme
    let isDark: Bool
    @ViewBuilder let content: Content

    init(
        theme: PaperTheme,
        isDark: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.isDark = isDark
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.editorBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
            .shadow(color: theme.shadow.opacity(isDark ? 0.22 : 0.1), radius: 22, y: 12)
    }
}

private struct NativeCodeTextView: NSViewRepresentable {
    var text: String
    var language: EditorFileFormat
    var selection: NSRange
    var fontSize: CGFloat
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
        view.update(text: text, selection: selection, language: language, fontSize: fontSize, showLineNumbers: showLineNumbers, theme: theme, isDark: isDark)
        context.coordinator.applyExternalUpdate = false
        return view
    }

    func updateNSView(_ nsView: EditorTextContainerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.containerView = nsView
        context.coordinator.applyExternalUpdate = true
        nsView.update(text: text, selection: selection, language: language, fontSize: fontSize, showLineNumbers: showLineNumbers, theme: theme, isDark: isDark)
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
            containerView?.markNeedsSyntaxRefresh()
            parent.onTextChange(textView.string, textView.selectedRange())
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !applyExternalUpdate, let textView = notification.object as? NSTextView else { return }
            parent.onSelectionChange(textView.selectedRange())
        }
    }
}

private final class EditorTextContainerView: NSView {
    let textView: NSTextView

    private let gutterScrollView = NSScrollView()
    private let gutterTextView: NSTextView
    private let editorScrollView = NSScrollView()
    private let stackView = NSStackView()
    private let gutterWidthConstraint: NSLayoutConstraint
    private let gutterWidth: CGFloat = 60

    private var currentTheme: PaperTheme?
    private var currentLanguage: EditorFileFormat = .plainText
    private var currentIsDark = false
    private var currentFontSize = WorkspaceStore.defaultEditorFontSize
    private var currentHighlightedLineRange: NSRange?
    private var needsSyntaxRefresh = false

    init(showLineNumbers: Bool) {
        textView = Self.makeEditorTextView()
        gutterTextView = Self.makeGutterTextView()
        gutterWidthConstraint = gutterScrollView.widthAnchor.constraint(equalToConstant: showLineNumbers ? gutterWidth : 0)
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
        fontSize: CGFloat,
        showLineNumbers: Bool,
        theme: PaperTheme,
        isDark: Bool
    ) {
        let editorBackground = NSColor(theme.editorBackground)
        let gutterBackground = NSColor(theme.secondaryElevatedBackground.opacity(isDark ? 0.72 : 0.92))
        layer?.backgroundColor = editorBackground.cgColor
        editorScrollView.backgroundColor = editorBackground
        textView.backgroundColor = editorBackground
        gutterScrollView.backgroundColor = gutterBackground
        gutterTextView.backgroundColor = gutterBackground
        textView.insertionPointColor = NSColor(theme.accent)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(theme.selection),
            .foregroundColor: NSColor(theme.textPrimary),
        ]
        editorScrollView.scrollerKnobStyle = isDark ? .light : .dark

        gutterWidthConstraint.constant = showLineNumbers ? gutterWidth : 0
        gutterScrollView.isHidden = !showLineNumbers

        let needsHighlightRefresh = needsSyntaxRefresh
            || textView.string != text
            || currentLanguage != language
            || currentIsDark != isDark
            || currentFontSize != fontSize
        let selectionChanged = textView.selectedRange() != selection

        currentLanguage = language
        currentTheme = theme
        currentIsDark = isDark
        currentFontSize = fontSize

        if needsHighlightRefresh {
            let highlighted = NSMutableAttributedString(attributedString: SyntaxHighlighter.highlightedText(
                for: text,
                language: language,
                theme: theme,
                isDark: isDark,
                fontSize: fontSize
            ))
            applyCurrentLineHighlight(in: highlighted, selection: selection, theme: theme)
            textView.textStorage?.setAttributedString(highlighted)
            textView.typingAttributes = SyntaxHighlighter.baseAttributes(theme: theme, fontSize: fontSize)
            refreshLineNumbers(selection: selection)
            needsSyntaxRefresh = false
        } else if selectionChanged {
            refreshCurrentLineHighlight(selection: selection, theme: theme)
            refreshLineNumbers(selection: selection)
        } else if textView.typingAttributes[.foregroundColor] == nil {
            textView.typingAttributes = SyntaxHighlighter.baseAttributes(theme: theme, fontSize: fontSize)
        }

        if selectionChanged {
            textView.setSelectedRange(selection)
            textView.scrollRangeToVisible(selection)
        }
    }

    func markNeedsSyntaxRefresh() {
        needsSyntaxRefresh = true
    }

    func refreshLineNumbers(selection: NSRange? = nil) {
        let lineCount = max(1, textView.string.components(separatedBy: "\n").count)
        let activeLine = currentLineNumber(for: selection ?? textView.selectedRange())
        let paragraphStyle = SyntaxHighlighter.paragraphStyle(fontSize: currentFontSize)
        paragraphStyle.alignment = .right
        let attributed = NSMutableAttributedString()

        for line in 1...lineCount {
            let isActiveLine = line == activeLine
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(
                    ofSize: max(11, currentFontSize - 2),
                    weight: isActiveLine ? .semibold : .medium
                ),
                .foregroundColor: NSColor(
                    isActiveLine
                        ? currentTheme?.accent ?? Color(nsColor: .labelColor)
                        : currentTheme?.textSubtle ?? Color(nsColor: .secondaryLabelColor)
                ),
                .paragraphStyle: paragraphStyle,
            ]
            attributed.append(NSAttributedString(string: "\(line)"))
            if line < lineCount {
                attributed.append(NSAttributedString(string: "\n", attributes: attributes))
            }
            attributed.addAttributes(attributes, range: NSRange(location: attributed.length - "\(line)".count - (line < lineCount ? 1 : 0), length: "\(line)".count))
        }

        gutterTextView.textStorage?.setAttributedString(attributed)
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
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 18, height: 20)
        textView.textContainer?.lineFragmentPadding = 2
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: WorkspaceStore.defaultEditorFontSize, weight: .regular)
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.drawsBackground = true

        editorScrollView.drawsBackground = true
        editorScrollView.hasVerticalScroller = true
        editorScrollView.hasHorizontalScroller = true
        editorScrollView.borderType = .noBorder
        editorScrollView.documentView = textView
        editorScrollView.contentView.postsBoundsChangedNotifications = true
        editorScrollView.scrollerKnobStyle = currentIsDark ? .light : .dark
    }

    private func configureGutter() {
        gutterTextView.isEditable = false
        gutterTextView.isSelectable = false
        gutterTextView.drawsBackground = true
        gutterTextView.textContainerInset = NSSize(width: 8, height: 20)
        gutterTextView.textContainer?.lineFragmentPadding = 0
        gutterTextView.font = NSFont.monospacedSystemFont(ofSize: max(11, WorkspaceStore.defaultEditorFontSize - 2), weight: .medium)

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

    private func currentLineNumber(for selection: NSRange) -> Int {
        let location = min(selection.location, (textView.string as NSString).length)
        let prefix = (textView.string as NSString).substring(to: location)
        return max(1, prefix.components(separatedBy: "\n").count)
    }

    private func refreshCurrentLineHighlight(selection: NSRange, theme: PaperTheme) {
        guard let textStorage = textView.textStorage else { return }
        clearCurrentLineHighlight(in: textStorage)
        applyCurrentLineHighlight(in: textStorage, selection: selection, theme: theme)
    }

    private func clearCurrentLineHighlight(in attributed: NSMutableAttributedString) {
        guard let currentHighlightedLineRange else { return }
        let safeLength = attributed.length
        guard NSMaxRange(currentHighlightedLineRange) <= safeLength else {
            self.currentHighlightedLineRange = nil
            return
        }
        attributed.removeAttribute(.backgroundColor, range: currentHighlightedLineRange)
        self.currentHighlightedLineRange = nil
    }

    private func applyCurrentLineHighlight(
        in attributed: NSMutableAttributedString,
        selection: NSRange,
        theme: PaperTheme
    ) {
        clearCurrentLineHighlight(in: attributed)
        let text = attributed.string as NSString
        guard text.length > 0 else { return }
        let location = min(selection.location, text.length - 1)
        let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
        attributed.addAttribute(.backgroundColor, value: NSColor(theme.currentLine), range: lineRange)
        currentHighlightedLineRange = lineRange
    }

    private static func makeEditorTextView() -> NSTextView {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        return NSTextView(frame: .zero, textContainer: textContainer)
    }

    private static func makeGutterTextView() -> NSTextView {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 60, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        return NSTextView(frame: .zero, textContainer: textContainer)
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
        isDark: Bool,
        fontSize: CGFloat
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes(theme: theme, fontSize: fontSize))

        switch language {
        case .json:
            highlightJSON(in: attributed, theme: theme, isDark: isDark, fontSize: fontSize)
        case .yaml:
            highlightYAML(in: attributed, theme: theme, isDark: isDark, fontSize: fontSize)
        case .toml:
            highlightTOML(in: attributed, theme: theme, isDark: isDark, fontSize: fontSize)
        case .xml, .plist:
            highlightXML(in: attributed, theme: theme, isDark: isDark, fontSize: fontSize)
        case .shellScript:
            highlightShell(in: attributed, theme: theme, isDark: isDark, fontSize: fontSize)
        case .markdown, .plainText:
            break
        }

        return attributed
    }

    static func baseAttributes(theme: PaperTheme, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor(theme.textPrimary),
            .paragraphStyle: paragraphStyle(fontSize: fontSize),
        ]
    }

    static func paragraphStyle(fontSize: CGFloat) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let lineHeight = ceil(font.ascender - font.descender + font.leading + 2)
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        style.paragraphSpacing = 0
        return style
    }

    private static func highlightShell(
        in attributed: NSMutableAttributedString,
        theme: PaperTheme,
        isDark: Bool,
        fontSize: CGFloat
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
                shebangColor: shebangColor,
                fontSize: fontSize
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
        shebangColor: NSColor,
        fontSize: CGFloat
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
                    attributed.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold), range: range)
                }
                continue
            }

            index += 1
        }
    }

    private static func highlightJSON(
        in attributed: NSMutableAttributedString,
        theme: PaperTheme,
        isDark: Bool,
        fontSize: CGFloat
    ) {
        let keyAttributes = tokenAttributes(
            color: NSColor(isDark ? Color(hex: "#F5C26B") : Color(hex: "#9A5B00")),
            font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        )
        let stringAttributes = tokenAttributes(color: NSColor(isDark ? Color(hex: "#A8E6A3") : Color(hex: "#1F7A2F")))
        let numberAttributes = tokenAttributes(color: NSColor(isDark ? Color(hex: "#7DD3FC") : Color(hex: "#005A9C")))
        let literalAttributes = tokenAttributes(
            color: NSColor(isDark ? Color(hex: "#FF9F7A") : Color(hex: "#B42318")),
            font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        )

        apply(pattern: #""(?:\\.|[^"\\])*""#, attributes: stringAttributes, to: attributed)
        apply(pattern: #""(?:\\.|[^"\\])*"(?=\s*:)"#, attributes: keyAttributes, to: attributed)
        apply(pattern: #"(?<![\w.])-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?"#, attributes: numberAttributes, to: attributed)
        apply(pattern: #"\b(?:true|false|null)\b"#, attributes: literalAttributes, to: attributed)
    }

    private static func highlightYAML(
        in attributed: NSMutableAttributedString,
        theme: PaperTheme,
        isDark: Bool,
        fontSize: CGFloat
    ) {
        let keyAttributes = tokenAttributes(
            color: NSColor(isDark ? Color(hex: "#F5C26B") : Color(hex: "#9A5B00")),
            font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        )
        let stringAttributes = tokenAttributes(color: NSColor(isDark ? Color(hex: "#A8E6A3") : Color(hex: "#1F7A2F")))
        let numberAttributes = tokenAttributes(color: NSColor(isDark ? Color(hex: "#7DD3FC") : Color(hex: "#005A9C")))
        let literalAttributes = tokenAttributes(
            color: NSColor(isDark ? Color(hex: "#FF9F7A") : Color(hex: "#B42318")),
            font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        )
        let commentAttributes = tokenAttributes(color: NSColor(theme.textSubtle))

        apply(pattern: #"(?m)^(\s*-\s*)?([^\s:#][^:#\n]*?)(?=\s*:)"#, attributes: keyAttributes, to: attributed, group: 2)
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, attributes: stringAttributes, to: attributed)
        apply(pattern: #"(?<![\w.])-?(?:0|[1-9]\d*)(?:\.\d+)?"#, attributes: numberAttributes, to: attributed)
        apply(pattern: #"\b(?:true|false|null|yes|no|on|off)\b"#, attributes: literalAttributes, to: attributed)
        apply(pattern: #"(?m)#.*$"#, attributes: commentAttributes, to: attributed)
    }

    private static func highlightTOML(
        in attributed: NSMutableAttributedString,
        theme: PaperTheme,
        isDark: Bool,
        fontSize: CGFloat
    ) {
        let keyAttributes = tokenAttributes(
            color: NSColor(isDark ? Color(hex: "#F5C26B") : Color(hex: "#9A5B00")),
            font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        )
        let sectionAttributes = tokenAttributes(
            color: NSColor(isDark ? Color(hex: "#FF9F7A") : Color(hex: "#B42318")),
            font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        )
        let stringAttributes = tokenAttributes(color: NSColor(isDark ? Color(hex: "#A8E6A3") : Color(hex: "#1F7A2F")))
        let numberAttributes = tokenAttributes(color: NSColor(isDark ? Color(hex: "#7DD3FC") : Color(hex: "#005A9C")))
        let literalAttributes = tokenAttributes(
            color: NSColor(isDark ? Color(hex: "#FF9F7A") : Color(hex: "#B42318")),
            font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        )
        let commentAttributes = tokenAttributes(color: NSColor(theme.textSubtle))

        apply(pattern: #"(?m)^\s*(\[{1,2}[^\]\n]+\]{1,2})"#, attributes: sectionAttributes, to: attributed, group: 1)
        apply(pattern: #"(?m)^\s*([A-Za-z0-9_.-]+)\s*(?==)"#, attributes: keyAttributes, to: attributed, group: 1)
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, attributes: stringAttributes, to: attributed)
        apply(pattern: #"(?<![\w.])-?(?:0|[1-9]\d*)(?:\.\d+)?"#, attributes: numberAttributes, to: attributed)
        apply(pattern: #"\b(?:true|false)\b"#, attributes: literalAttributes, to: attributed)
        apply(pattern: #"(?m)#.*$"#, attributes: commentAttributes, to: attributed)
    }

    private static func highlightXML(
        in attributed: NSMutableAttributedString,
        theme: PaperTheme,
        isDark: Bool,
        fontSize: CGFloat
    ) {
        let tagAttributes = tokenAttributes(
            color: NSColor(isDark ? Color(hex: "#FF9F7A") : Color(hex: "#B42318")),
            font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        )
        let attributeNameAttributes = tokenAttributes(
            color: NSColor(isDark ? Color(hex: "#F5C26B") : Color(hex: "#9A5B00")),
            font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        )
        let stringAttributes = tokenAttributes(color: NSColor(isDark ? Color(hex: "#A8E6A3") : Color(hex: "#1F7A2F")))
        let commentAttributes = tokenAttributes(color: NSColor(theme.textSubtle))

        apply(pattern: #"<!--[\s\S]*?-->"#, options: [.dotMatchesLineSeparators], attributes: commentAttributes, to: attributed)
        apply(pattern: #"</?\s*([A-Za-z_][A-Za-z0-9_.:-]*)"#, attributes: tagAttributes, to: attributed, group: 1)
        apply(pattern: #"\s([A-Za-z_][A-Za-z0-9_.:-]*)(?=\s*=)"#, attributes: attributeNameAttributes, to: attributed, group: 1)
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, attributes: stringAttributes, to: attributed)
    }

    private static func tokenAttributes(
        color: NSColor,
        font: NSFont? = nil
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]
        if let font {
            attributes[.font] = font
        }
        return attributes
    }

    private static func apply(
        pattern: String,
        options: NSRegularExpression.Options = [],
        attributes: [NSAttributedString.Key: Any],
        to attributed: NSMutableAttributedString,
        group: Int = 0
    ) {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let fullRange = NSRange(location: 0, length: (attributed.string as NSString).length)

        expression.enumerateMatches(in: attributed.string, options: [], range: fullRange) { match, _, _ in
            guard let match else { return }
            let targetRange = match.range(at: group)
            guard targetRange.location != NSNotFound else { return }
            attributed.addAttributes(attributes, range: targetRange)
        }
    }
}
