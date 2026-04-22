import AppKit
import Foundation
import UniformTypeIdentifiers

enum EditorFileFormat: String, CaseIterable, Codable {
    case markdown
    case json
    case yaml
    case toml
    case xml
    case plist
    case plainText

    init(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "md", "markdown":
            self = .markdown
        case "json":
            self = .json
        case "yaml", "yml":
            self = .yaml
        case "toml":
            self = .toml
        case "xml":
            self = .xml
        case "plist":
            self = .plist
        default:
            self = .plainText
        }
    }

    var displayName: String {
        switch self {
        case .markdown: "Markdown"
        case .json: "JSON"
        case .yaml: "YAML"
        case .toml: "TOML"
        case .xml: "XML"
        case .plist: "Property List"
        case .plainText: "Plain Text"
        }
    }

    var iconName: String {
        switch self {
        case .markdown: "doc.text"
        case .json: "curlybraces"
        case .yaml: "line.3.horizontal"
        case .toml: "slider.horizontal.3"
        case .xml: "chevron.left.forwardslash.chevron.right"
        case .plist: "list.bullet.rectangle"
        case .plainText: "doc.plaintext"
        }
    }

    var accentHex: String {
        switch self {
        case .markdown: "#0A84FF"
        case .json: "#FFD60A"
        case .yaml: "#BF5AF2"
        case .toml: "#32D74B"
        case .xml: "#FF9500"
        case .plist: "#FF375F"
        case .plainText: "#8E8E93"
        }
    }

    var preferredFilenameExtension: String? {
        switch self {
        case .markdown:
            "md"
        case .json:
            "json"
        case .yaml:
            "yaml"
        case .toml:
            "toml"
        case .xml:
            "xml"
        case .plist:
            "plist"
        case .plainText:
            "txt"
        }
    }

    var contentType: UTType? {
        guard let preferredFilenameExtension else { return nil }
        return UTType(filenameExtension: preferredFilenameExtension)
    }
}

enum EditorViewMode: String, CaseIterable, Codable {
    case edit
    case split
    case wysiwyg
}

enum SidebarSection: String, CaseIterable, Codable, Identifiable {
    case pinned
    case recent
    case explorer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinned: "Open Tabs"
        case .recent: "Recent Files"
        case .explorer: "Workspace"
        }
    }

    var iconName: String {
        switch self {
        case .pinned: "doc.on.doc"
        case .recent: "clock.arrow.circlepath"
        case .explorer: "folder"
        }
    }
}

enum PreferencePane: String, CaseIterable, Codable, Identifiable {
    case general
    case editor
    case appearance
    case shortcuts

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .general: "gearshape"
        case .editor: "text.cursor"
        case .appearance: "paintpalette"
        case .shortcuts: "command"
        }
    }
}

enum ThemePalette: String, CaseIterable, Codable {
    case light
    case dark
    case system

    var displayName: String {
        switch self {
        case .light: "PaperEdit Light"
        case .dark: "PaperEdit Dark"
        case .system: "Auto (System)"
        }
    }
}

enum SidebarMaterialStyle: String, CaseIterable, Codable {
    case translucent
    case opaque

    var displayName: String { rawValue.capitalized }
}

enum AccentSwatch: String, CaseIterable, Codable, Identifiable {
    case blue = "#0A84FF"
    case red = "#FF3B30"
    case green = "#32D74B"
    case orange = "#FF9F0A"
    case purple = "#BF5AF2"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: "Blue"
        case .red: "Red"
        case .green: "Green"
        case .orange: "Orange"
        case .purple: "Purple"
        }
    }
}

enum DemoScene: String, CaseIterable, Identifiable {
    case lightMarkdownSplit
    case darkJSON
    case lightYAML
    case emptyState
    case settings
    case commandPalette

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lightMarkdownSplit: "1. Light + Markdown"
        case .darkJSON: "2. Dark + JSON"
        case .lightYAML: "3. Light + YAML"
        case .emptyState: "4. Empty State"
        case .settings: "5. Preferences"
        case .commandPalette: "6. Command Palette"
        }
    }
}

enum FileTreeNodeKind: String, Codable {
    case file
    case folder
    case group
    case project
}

struct FileTreeNode: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var kind: FileTreeNodeKind
    var format: EditorFileFormat?
    var sourceURL: URL?
    var children: [FileTreeNode]

    init(
        id: String? = nil,
        name: String,
        kind: FileTreeNodeKind,
        format: EditorFileFormat? = nil,
        sourceURL: URL? = nil,
        children: [FileTreeNode] = []
    ) {
        self.id = id ?? sourceURL?.path ?? "\(kind.rawValue):\(name)"
        self.name = name
        self.kind = kind
        self.format = format
        self.sourceURL = sourceURL
        self.children = children
    }
}

struct EditorFoldMarker: Identifiable, Hashable {
    let id = UUID()
    let line: Int
    let level: Int
    var isFolded: Bool
}

struct EditorStatus: Equatable {
    var format: String
    var encoding: String
    var line: Int
    var column: Int
    var metrics: String
    var gitBranch: String
    var lspOnline: Bool

    static let empty = EditorStatus(
        format: "Ready",
        encoding: "",
        line: 1,
        column: 1,
        metrics: "",
        gitBranch: "main",
        lspOnline: true
    )
}

struct EditorTab: Identifiable, Hashable {
    let id: UUID
    var name: String
    var format: EditorFileFormat
    var text: String
    var sourceURL: URL?
    var isDirty: Bool
    var selection: NSRange
    var foldMarkers: [EditorFoldMarker]
    var showsFolding: Bool

    init(
        id: UUID = UUID(),
        name: String,
        format: EditorFileFormat,
        text: String,
        sourceURL: URL? = nil,
        isDirty: Bool = false,
        selection: NSRange = NSRange(location: 0, length: 0),
        foldMarkers: [EditorFoldMarker] = [],
        showsFolding: Bool = false
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.text = text
        self.sourceURL = sourceURL
        self.isDirty = isDirty
        self.selection = selection
        self.foldMarkers = foldMarkers
        self.showsFolding = showsFolding
    }
}

enum CommandAction: Hashable {
    case openSettings(PreferencePane)
    case toggleTheme
    case toggleSidebar
    case newFile
    case openFile
    case openFolder
    case saveFile
    case saveFileAs
    case activateScene(DemoScene)
    case setMarkdownMode(EditorViewMode)
}

struct CommandItem: Identifiable, Hashable {
    let id: UUID
    var category: String
    var title: String
    var subtitle: String
    var shortcut: String?
    var symbolName: String
    var keywords: [String]
    var action: CommandAction

    init(
        id: UUID = UUID(),
        category: String,
        title: String,
        subtitle: String,
        shortcut: String? = nil,
        symbolName: String,
        keywords: [String] = [],
        action: CommandAction
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.shortcut = shortcut
        self.symbolName = symbolName
        self.keywords = keywords
        self.action = action
    }
}

@MainActor
final class SettingsWindowModel: ObservableObject {
    @Published var selectedPane: PreferencePane = .appearance
}

@MainActor
final class CommandPaletteModel: ObservableObject {
    @Published var query = ""
    @Published var selectedIndex = 0

    func moveSelection(delta: Int, itemCount: Int) {
        guard itemCount > 0 else {
            selectedIndex = 0
            return
        }

        selectedIndex = max(0, min(itemCount - 1, selectedIndex + delta))
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }
}

enum EditorSampleFactory {
    static func markdownTab() -> EditorTab {
        EditorTab(
            name: "README.md",
            format: .markdown,
            text: """
            # PaperEdit

            A lightweight, native macOS text editor designed for configuration files and documentation.

            ## Features

            - **Minimalist**: Focus on your content.
            - **Native feel**: Strictly follows Apple Human Interface Guidelines.
            - **Fast**: Built for speed and clarity.

            > Like a clean sheet of paper.
            """,
            selection: NSRange(location: 16, length: 0)
        )
    }

    static func jsonTab(folded: Bool = true) -> EditorTab {
        let text: String
        if folded {
            text = """
            {
              "editor": { ... },
              "files": {
                "trimTrailingWhitespace": true,
                "insertFinalNewline": true
              },
              "theme": "PaperEdit Dark"
            }
            """
        } else {
            text = """
            {
              "editor": {
                "fontFamily": "SF Mono",
                "fontSize": 14,
                "lineHeight": 1.6,
                "renderLineHighlight": "all",
                "minimap": { "enabled": false }
              },
              "files": {
                "trimTrailingWhitespace": true,
                "insertFinalNewline": true
              },
              "theme": "PaperEdit Dark"
            }
            """
        }

        return EditorTab(
            name: "settings.json",
            format: .json,
            text: text,
            selection: NSRange(location: 48, length: 0),
            foldMarkers: [
                EditorFoldMarker(line: 2, level: 0, isFolded: folded),
                EditorFoldMarker(line: 3, level: 1, isFolded: true),
                EditorFoldMarker(line: 8, level: 0, isFolded: false),
            ],
            showsFolding: true
        )
    }

    static func yamlTab() -> EditorTab {
        EditorTab(
            name: "docker-compose.yaml",
            format: .yaml,
            text: """
            version: "3.8"

            services:
              web:
                image: nginx:alpine
                ports:
                  - "8080:80"
                volumes:
                  - ./public:/usr/share/nginx/html
                restart: always
            """,
            selection: NSRange(location: 113, length: 0)
        )
    }

    static func tomlTab() -> EditorTab {
        EditorTab(
            name: "Cargo.toml",
            format: .toml,
            text: """
            [package]
            name = "paperedit-core"
            version = "0.1.0"
            edition = "2021"

            [dependencies]
            serde = { version = "1.0", features = ["derive"] }
            tokio = "1.28.0"
            """,
            selection: NSRange(location: 99, length: 0)
        )
    }

    static func xmlTab() -> EditorTab {
        EditorTab(
            name: "layout.xml",
            format: .xml,
            text: """
            <?xml version="1.0" encoding="UTF-8"?>
            <configuration>
              <window>
                <width>800</width>
                <height>600</height>
                <fullscreen>false</fullscreen>
              </window>
              <theme>light</theme>
            </configuration>
            """,
            selection: NSRange(location: 105, length: 0)
        )
    }

    static func plistTab() -> EditorTab {
        EditorTab(
            name: "Info.plist",
            format: .plist,
            text: """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>CFBundleIdentifier</key>
              <string>com.paperedit.app</string>
              <key>CFBundleName</key>
              <string>PaperEdit</string>
            </dict>
            </plist>
            """,
            selection: NSRange(location: 187, length: 0)
        )
    }

    static func untitledTab(index: Int) -> EditorTab {
        EditorTab(
            name: "Untitled \(index).md",
            format: .markdown,
            text: "# Untitled\n\nStart typing here…",
            selection: NSRange(location: 12, length: 0)
        )
    }

    static let pinnedFiles: [FileTreeNode] = [
        FileTreeNode(
            name: "Core Configs",
            kind: .group,
            children: [
                FileTreeNode(name: "settings.json", kind: .file, format: .json),
                FileTreeNode(name: "Info.plist", kind: .file, format: .plist),
                FileTreeNode(name: "layout.xml", kind: .file, format: .xml),
            ]
        ),
        FileTreeNode(
            name: "Documentation",
            kind: .group,
            children: [
                FileTreeNode(name: "README.md", kind: .file, format: .markdown),
                FileTreeNode(name: "Cargo.toml", kind: .file, format: .toml),
            ]
        ),
    ]

    static let recentProjects: [FileTreeNode] = [
        FileTreeNode(
            name: "Recent Work",
            kind: .group,
            children: [
                FileTreeNode(name: "PaperEdit-macOS", kind: .project),
                FileTreeNode(name: "notes-workspace", kind: .project),
            ]
        )
    ]

    static let explorerFiles: [FileTreeNode] = [
        FileTreeNode(
            name: "PaperEdit",
            kind: .folder,
            children: [
                FileTreeNode(name: "README.md", kind: .file, format: .markdown),
                FileTreeNode(name: "settings.json", kind: .file, format: .json),
                FileTreeNode(name: "docker-compose.yaml", kind: .file, format: .yaml),
                FileTreeNode(name: "Info.plist", kind: .file, format: .plist),
                FileTreeNode(
                    name: "Sources",
                    kind: .folder,
                    children: [
                        FileTreeNode(name: "PaperEditApp.swift", kind: .file, format: .plainText),
                        FileTreeNode(name: "WorkspaceStore.swift", kind: .file, format: .plainText),
                    ]
                ),
                FileTreeNode(name: "Cargo.toml", kind: .file, format: .toml),
            ]
        )
    ]
}
