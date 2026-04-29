import CloudKit
import Foundation

final class CloudKitPreferencesClient: CloudPreferencesClient, @unchecked Sendable {
    private let containerIdentifier: String?
    private let recordID = CKRecord.ID(recordName: "default")
    private let recordType = "PaperEditPreferences"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Lazy: CKContainer init asserts the bundle declares the matching iCloud
    // entitlement. Constructing it at app launch crashes any unsigned dev build.
    // Deferring it to first sync means debug runs (sync defaulting to off) launch fine.
    private let containerLock = NSLock()
    private var resolvedDatabase: CKDatabase?
    private var resolvedContainer: CKContainer?

    init(containerIdentifier: String? = nil) {
        self.containerIdentifier = containerIdentifier

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    private func container() -> CKContainer {
        containerLock.lock()
        defer { containerLock.unlock() }
        if let resolvedContainer { return resolvedContainer }
        let made: CKContainer = {
            if let containerIdentifier {
                return CKContainer(identifier: containerIdentifier)
            }
            return CKContainer.default()
        }()
        resolvedContainer = made
        resolvedDatabase = made.privateCloudDatabase
        return made
    }

    private func database() -> CKDatabase {
        containerLock.lock()
        if let resolvedDatabase {
            containerLock.unlock()
            return resolvedDatabase
        }
        containerLock.unlock()
        return container().privateCloudDatabase
    }

    func accountStatus() async throws -> CloudAccountStatus {
        let status = try await container().accountStatus()
        switch status {
        case .available:
            return .available
        case .noAccount:
            return .noAccount
        case .restricted, .temporarilyUnavailable:
            return .restricted
        case .couldNotDetermine:
            return .couldNotDetermine("iCloud account state is unknown.")
        @unknown default:
            return .couldNotDetermine("Unknown iCloud account state.")
        }
    }

    func fetchSnapshot() async throws -> WorkspaceSyncSnapshot? {
        let database = database()
        do {
            let record = try await database.record(for: recordID)
            guard let payloadData = record["payloadData"] as? Data else { return nil }
            return try decoder.decode(WorkspaceSyncSnapshot.self, from: payloadData)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func saveSnapshot(_ snapshot: WorkspaceSyncSnapshot) async throws {
        let database = database()
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        record["payloadData"] = try encoder.encode(snapshot)
        record["updatedAt"] = snapshot.updatedAt
        record["schemaVersion"] = snapshot.schemaVersion
        _ = try await database.save(record)
    }
}
