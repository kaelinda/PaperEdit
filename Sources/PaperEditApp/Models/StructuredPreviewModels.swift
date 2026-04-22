import Foundation

enum StructuredPreviewKind {
    case root
    case object
    case array
    case property
    case value
    case section
    case element
    case attribute
    case item

    var iconName: String {
        switch self {
        case .root: "square.stack.3d.up"
        case .object: "curlybraces"
        case .array: "list.bullet"
        case .property: "key"
        case .value: "text.alignleft"
        case .section: "folder"
        case .element: "chevron.left.forwardslash.chevron.right"
        case .attribute: "at"
        case .item: "circle.grid.2x1"
        }
    }
}

struct StructuredPreviewNode: Identifiable {
    let id = UUID()
    var title: String
    var value: String?
    var kind: StructuredPreviewKind
    var children: [StructuredPreviewNode]

    init(
        title: String,
        value: String? = nil,
        kind: StructuredPreviewKind,
        children: [StructuredPreviewNode] = []
    ) {
        self.title = title
        self.value = value
        self.kind = kind
        self.children = children
    }
}

struct StructuredPreviewDocument {
    var title: String
    var subtitle: String
    var nodes: [StructuredPreviewNode]
    var diagnostics: [String] = []
}

enum StructuredPreviewBuilder {
    static func build(format: EditorFileFormat, text: String) -> StructuredPreviewDocument {
        switch format {
        case .json:
            jsonDocument(from: text)
        case .yaml:
            outlineDocument(formatName: "YAML", rootTitle: "YAML Document", text: text, parser: parseYAML(_:))
        case .toml:
            outlineDocument(formatName: "TOML", rootTitle: "TOML Document", text: text, parser: parseTOML(_:))
        case .xml:
            xmlDocument(from: text)
        case .plist:
            plistDocument(from: text)
        case .markdown:
            StructuredPreviewDocument(
                title: "Markdown Document",
                subtitle: "Markdown uses the rendered preview.",
                nodes: []
            )
        case .shellScript:
            StructuredPreviewDocument(
                title: "Shell Script",
                subtitle: "Structured preview is not available for shell scripts.",
                nodes: [],
                diagnostics: ["Use syntax highlighting in the editor to inspect shell scripts."]
            )
        case .plainText:
            StructuredPreviewDocument(
                title: "Plain Text",
                subtitle: "Structured preview is not available for plain text.",
                nodes: [],
                diagnostics: ["This file type does not expose a structured preview."]
            )
        }
    }

    private static func jsonDocument(from text: String) -> StructuredPreviewDocument {
        do {
            let data = Data(text.utf8)
            let object = try JSONSerialization.jsonObject(with: data)
            let root = node(for: object, title: "JSON Root", kind: .root)
            return StructuredPreviewDocument(
                title: "JSON Structure",
                subtitle: summary(for: root),
                nodes: [root]
            )
        } catch {
            return StructuredPreviewDocument(
                title: "JSON Structure",
                subtitle: "Unable to parse JSON.",
                nodes: [],
                diagnostics: [error.localizedDescription]
            )
        }
    }

    private static func plistDocument(from text: String) -> StructuredPreviewDocument {
        do {
            let data = Data(text.utf8)
            var plistFormat = PropertyListSerialization.PropertyListFormat.xml
            let object = try PropertyListSerialization.propertyList(from: data, options: [], format: &plistFormat)
            let root = node(for: object, title: "Property List Root", kind: .root)
            return StructuredPreviewDocument(
                title: "Property List Structure",
                subtitle: summary(for: root),
                nodes: [root]
            )
        } catch {
            return StructuredPreviewDocument(
                title: "Property List Structure",
                subtitle: "Unable to parse property list.",
                nodes: [],
                diagnostics: [error.localizedDescription]
            )
        }
    }

    private static func xmlDocument(from text: String) -> StructuredPreviewDocument {
        let parserDelegate = XMLPreviewParserDelegate()
        let parser = XMLParser(data: Data(text.utf8))
        parser.delegate = parserDelegate

        guard parser.parse(), let rootElement = parserDelegate.root else {
            let message = parser.parserError?.localizedDescription ?? "XML document has no root element."
            return StructuredPreviewDocument(
                title: "XML Structure",
                subtitle: "Unable to parse XML.",
                nodes: [],
                diagnostics: [message]
            )
        }

        let root = node(for: rootElement)
        return StructuredPreviewDocument(
            title: "XML Structure",
            subtitle: summary(for: root),
            nodes: [root]
        )
    }

    private static func outlineDocument(
        formatName: String,
        rootTitle: String,
        text: String,
        parser: (String) -> (nodes: [StructuredPreviewNode], diagnostics: [String])
    ) -> StructuredPreviewDocument {
        let result = parser(text)
        let root = StructuredPreviewNode(title: rootTitle, kind: .root, children: result.nodes)

        return StructuredPreviewDocument(
            title: "\(formatName) Structure",
            subtitle: summary(for: root),
            nodes: [root],
            diagnostics: result.diagnostics
        )
    }

    private static func node(for object: Any, title: String, kind: StructuredPreviewKind) -> StructuredPreviewNode {
        if let dictionary = object as? NSDictionary {
            let keys = dictionary.allKeys
                .map { String(describing: $0) }
                .sorted()
            let children = keys.map { key in
                node(for: dictionary[key] ?? NSNull(), title: key, kind: .property)
            }
            return StructuredPreviewNode(title: title, kind: kind == .property ? .object : kind, children: children)
        }

        if let dictionary = object as? [String: Any] {
            let children = dictionary.keys.sorted().map { key in
                node(for: dictionary[key] ?? NSNull(), title: key, kind: .property)
            }
            return StructuredPreviewNode(title: title, kind: kind == .property ? .object : kind, children: children)
        }

        if let array = object as? NSArray {
            let children = array.enumerated().map { index, value in
                node(for: value, title: "[\(index)]", kind: .item)
            }
            return StructuredPreviewNode(title: title, kind: kind == .property ? .array : kind, children: children)
        }

        if let array = object as? [Any] {
            let children = array.enumerated().map { index, value in
                node(for: value, title: "[\(index)]", kind: .item)
            }
            return StructuredPreviewNode(title: title, kind: kind == .property ? .array : kind, children: children)
        }

        return StructuredPreviewNode(
            title: title,
            value: scalarDescription(for: object),
            kind: kind == .root ? .value : kind
        )
    }

    private static func node(for element: XMLPreviewElement) -> StructuredPreviewNode {
        var children = element.attributes.sorted { $0.name < $1.name }.map { attribute in
            StructuredPreviewNode(title: attribute.name, value: attribute.value, kind: .attribute)
        }
        children += element.children.map(node(for:))

        let trimmedText = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            children.append(StructuredPreviewNode(title: "Text", value: compact(trimmedText), kind: .value))
        }

        return StructuredPreviewNode(title: element.name, kind: .element, children: children)
    }

    private static func parseYAML(_ text: String) -> (nodes: [StructuredPreviewNode], diagnostics: [String]) {
        let root = MutablePreviewNode(title: "YAML Document", kind: .root)
        var stack: [(indent: Int, node: MutablePreviewNode)] = [(-1, root)]
        var diagnostics: [String] = []

        for (lineIndex, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let indent = rawLine.prefix { $0 == " " }.count
            while let last = stack.last, last.indent >= indent {
                stack.removeLast()
            }

            guard let parent = stack.last?.node else { continue }
            let node = yamlNode(from: trimmed, lineNumber: lineIndex + 1, diagnostics: &diagnostics)
            parent.children.append(node)
            if node.value == nil {
                stack.append((indent, node))
            }
        }

        return (root.children.map { $0.structuredNode }, diagnostics)
    }

    private static func yamlNode(
        from line: String,
        lineNumber: Int,
        diagnostics: inout [String]
    ) -> MutablePreviewNode {
        if line.hasPrefix("- ") {
            let content = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if let pair = splitMapping(content, separator: ":") {
                return MutablePreviewNode(title: pair.key, value: pair.value, kind: .item)
            }
            return MutablePreviewNode(title: "Item \(lineNumber)", value: content.isEmpty ? nil : content, kind: .item)
        }

        if let pair = splitMapping(line, separator: ":") {
            return MutablePreviewNode(
                title: pair.key,
                value: pair.value,
                kind: pair.value == nil ? .section : .property
            )
        }

        diagnostics.append("Line \(lineNumber) could not be mapped to a key or list item.")
        return MutablePreviewNode(title: "Line \(lineNumber)", value: line, kind: .value)
    }

    private static func parseTOML(_ text: String) -> (nodes: [StructuredPreviewNode], diagnostics: [String]) {
        let root = MutablePreviewNode(title: "TOML Document", kind: .root)
        var sections: [String: MutablePreviewNode] = [:]
        var currentSection = root
        var diagnostics: [String] = []

        for (lineIndex, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let line = stripTOMLComment(from: rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("[[") && line.hasSuffix("]]") {
                let name = String(line.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                currentSection = appendTOMLSection(named: name, kind: .array, to: root, sections: &sections)
                continue
            }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let name = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                currentSection = appendTOMLSection(named: name, kind: .section, to: root, sections: &sections)
                continue
            }

            guard let pair = splitMapping(line, separator: "=") else {
                diagnostics.append("Line \(lineIndex + 1) could not be mapped to a TOML key.")
                continue
            }

            currentSection.children.append(
                MutablePreviewNode(title: pair.key, value: pair.value, kind: .property)
            )
        }

        return (root.children.map { $0.structuredNode }, diagnostics)
    }

    private static func appendTOMLSection(
        named name: String,
        kind: StructuredPreviewKind,
        to root: MutablePreviewNode,
        sections: inout [String: MutablePreviewNode]
    ) -> MutablePreviewNode {
        if let existing = sections[name], kind != .array {
            return existing
        }

        let section = MutablePreviewNode(title: name, kind: kind)
        root.children.append(section)
        sections[name] = section
        return section
    }

    private static func splitMapping(_ text: String, separator: Character) -> (key: String, value: String?)? {
        guard let separatorIndex = text.firstIndex(of: separator) else { return nil }
        let key = String(text[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }

        let rawValue = String(text[text.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespaces)
        return (key, rawValue.isEmpty ? nil : compact(rawValue))
    }

    private static func stripTOMLComment(from line: String) -> String {
        var insideSingleQuote = false
        var insideDoubleQuote = false

        for (index, character) in line.enumerated() {
            if character == "'", !insideDoubleQuote {
                insideSingleQuote.toggle()
            } else if character == "\"", !insideSingleQuote {
                insideDoubleQuote.toggle()
            } else if character == "#", !insideSingleQuote, !insideDoubleQuote {
                return String(line.prefix(index))
            }
        }

        return line
    }

    private static func scalarDescription(for object: Any) -> String {
        switch object {
        case let value as String:
            return value
        case let value as Bool:
            return value ? "true" : "false"
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return value.boolValue ? "true" : "false"
            }
            return value.stringValue
        case _ as NSNull:
            return "null"
        case let value as Date:
            return value.formatted(date: .abbreviated, time: .standard)
        case let value as Data:
            return "\(value.count) bytes"
        default:
            return String(describing: object)
        }
    }

    private static func compact(_ value: String) -> String {
        let collapsed = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if collapsed.count > 160 {
            return "\(collapsed.prefix(157))..."
        }
        return collapsed
    }

    private static func summary(for node: StructuredPreviewNode) -> String {
        let descendantCount = countDescendants(of: node)
        switch descendantCount {
        case 0:
            return "No child nodes"
        case 1:
            return "1 child node"
        default:
            return "\(descendantCount) child nodes"
        }
    }

    private static func countDescendants(of node: StructuredPreviewNode) -> Int {
        node.children.reduce(node.children.count) { partialResult, child in
            partialResult + countDescendants(of: child)
        }
    }
}

private final class MutablePreviewNode {
    var title: String
    var value: String?
    var kind: StructuredPreviewKind
    var children: [MutablePreviewNode]

    init(
        title: String,
        value: String? = nil,
        kind: StructuredPreviewKind,
        children: [MutablePreviewNode] = []
    ) {
        self.title = title
        self.value = value
        self.kind = kind
        self.children = children
    }

    var structuredNode: StructuredPreviewNode {
        StructuredPreviewNode(
            title: title,
            value: value,
            kind: kind,
            children: children.map { $0.structuredNode }
        )
    }
}

private final class XMLPreviewElement {
    let name: String
    var attributes: [(name: String, value: String)]
    var text = ""
    var children: [XMLPreviewElement] = []

    init(name: String, attributes: [(name: String, value: String)]) {
        self.name = name
        self.attributes = attributes
    }
}

private final class XMLPreviewParserDelegate: NSObject, XMLParserDelegate {
    var root: XMLPreviewElement?
    private var stack: [XMLPreviewElement] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let element = XMLPreviewElement(
            name: qName ?? elementName,
            attributes: attributeDict.map { ($0.key, $0.value) }
        )

        if let parent = stack.last {
            parent.children.append(element)
        } else {
            root = element
        }

        stack.append(element)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        _ = stack.popLast()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }
}
