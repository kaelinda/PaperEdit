import CloudKit
import Foundation

final class CloudKitPreferencesClient: CloudPreferencesClient, @unchecked Sendable {
    private let container: CKContainer
    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: "default")
    private let recordType = "PaperEditPreferences"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(containerIdentifier: String? = nil) {
        if let containerIdentifier {
            container = CKContainer(identifier: containerIdentifier)
        } else {
            container = CKContainer.default()
        }
        database = container.privateCloudDatabase

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func accountStatus() async throws -> CloudAccountStatus {
        let status = try await container.accountStatus()
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
        do {
            let record = try await database.record(for: recordID)
            guard let payloadData = record["payloadData"] as? Data else { return nil }
            return try decoder.decode(WorkspaceSyncSnapshot.self, from: payloadData)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func saveSnapshot(_ snapshot: WorkspaceSyncSnapshot) async throws {
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
