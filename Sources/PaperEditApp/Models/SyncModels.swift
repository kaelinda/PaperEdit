import Foundation

struct WorkspaceSyncSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var updatedAt: Date
    var themeMode: ThemePalette
    var accentSwatch: AccentSwatch
    var sidebarMaterialStyle: SidebarMaterialStyle
    var sidebarSections: [SidebarSection]
    var editorFontSize: Double
    var favoriteFilePaths: [String]
    var recentFilePaths: [String]
    var workspaceRootPath: String?
}

enum CloudSyncStatus: Equatable {
    case idle
    case syncing
    case synced
    /// User-action-required state (not signed in, restricted account, permission denied).
    /// The Settings pane shows the message in `theme.danger` plus an `Open System Settings` button.
    case unavailable(String)
    /// Transient or recoverable error (network down, quota, rate-limit). Sync Now stays enabled.
    case failed(String)
}

enum CloudAccountStatus: Equatable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine(String)
}

protocol CloudPreferencesClient {
    /// Returns the current iCloud account state. Called before every sync attempt
    /// so the UI can surface `Sign in to iCloud to sync` instead of a CloudKit error.
    func accountStatus() async throws -> CloudAccountStatus
    func fetchSnapshot() async throws -> WorkspaceSyncSnapshot?
    func saveSnapshot(_ snapshot: WorkspaceSyncSnapshot) async throws
}
