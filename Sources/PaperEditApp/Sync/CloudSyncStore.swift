import CloudKit
import Foundation

@MainActor
final class CloudSyncStore: ObservableObject {
    @Published private(set) var status: CloudSyncStatus = .idle
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastErrorMessage: String?

    private let client: CloudPreferencesClient
    private let clock: () -> Date
    private var didLaunchSync = false

    init(client: CloudPreferencesClient, clock: @escaping () -> Date = Date.init) {
        self.client = client
        self.clock = clock
    }

    /// Idempotent guard for `.task`-triggered launch sync. Multiple calls during
    /// one app launch (e.g., view re-appearance) only fire the first one.
    func launchSyncIfNeeded(workspaceStore: WorkspaceStore) async {
        guard !didLaunchSync else { return }
        didLaunchSync = true
        await syncNow(workspaceStore: workspaceStore)
    }

    func syncNow(workspaceStore: WorkspaceStore) async {
        status = .syncing
        lastErrorMessage = nil

        // Pre-flight: surface account-required states before touching CloudKit.
        do {
            switch try await client.accountStatus() {
            case .available:
                break
            case .noAccount, .restricted:
                status = .unavailable("Sign in to iCloud to sync")
                return
            case .couldNotDetermine(let message):
                lastErrorMessage = message
                status = .failed(Self.networkRetryMessage)
                return
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            status = .failed(Self.networkRetryMessage)
            return
        }

        do {
            let localSnapshot = workspaceStore.makeSyncSnapshot(updatedAt: clock())
            do {
                if let remoteSnapshot = try await client.fetchSnapshot(),
                   remoteSnapshot.updatedAt > localSnapshot.updatedAt {
                    workspaceStore.applySyncSnapshot(remoteSnapshot)
                } else {
                    try await client.saveSnapshot(localSnapshot)
                }
            } catch is DecodingError {
                // Spec "Decode failure": discard remote, upload fresh local, stay silent in UI.
                lastErrorMessage = "Decoded remote snapshot failed; uploaded fresh local."
                try await client.saveSnapshot(localSnapshot)
            }

            lastSyncedAt = clock()
            status = .synced
        } catch {
            let (message, kind) = mapClientError(error)
            lastErrorMessage = error.localizedDescription
            switch kind {
            case .userActionRequired:
                status = .unavailable(message)
            case .transient:
                status = .failed(message)
            }
        }
    }

    private enum ErrorKind { case userActionRequired, transient }

    private static let networkRetryMessage = "Couldn't reach iCloud. Try again."

    private func mapClientError(_ error: Error) -> (String, ErrorKind) {
        guard let ck = error as? CKError else {
            return (Self.networkRetryMessage, .transient)
        }
        switch ck.code {
        case .notAuthenticated, .permissionFailure:
            return ("Sign in to iCloud to sync", .userActionRequired)
        case .quotaExceeded:
            return ("iCloud storage is full.", .transient)
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return (Self.networkRetryMessage, .transient)
        default:
            return (Self.networkRetryMessage, .transient)
        }
    }
}
