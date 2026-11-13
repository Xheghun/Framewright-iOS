import CryptoKit
import Foundation
import FramewrightAnalytics

public enum SessionStorageError: Error, Equatable, Sendable {
    case invalidLimits
    case notFound
    case retentionLimit
    case unsupportedStoreVersion(Int)
    case invalidStoredSession
}

/// A single writer for a caller-owned directory. Reads and writes on one instance are serialized.
public actor FramewrightSessionStore {
    private let directory: URL
    private let maximumSessions: Int
    private let maximumBytes: Int
    private let codec = DiagnosticEventJSONCodec()

    public init(directory: URL, maximumSessions: Int, maximumBytes: Int) throws {
        guard directory.isFileURL, maximumSessions > 0, maximumBytes > 0 else {
            throw SessionStorageError.invalidLimits
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory.standardizedFileURL
        self.maximumSessions = maximumSessions
        self.maximumBytes = maximumBytes
    }

    /// Returns only after atomic replacement of the committed snapshot. This is not a power-loss guarantee.
    public func save(_ snapshot: SessionSnapshot) throws {
        let file = url(for: snapshot.sessionId)
        let records = try files()
        let existing = records.contains { $0.lastPathComponent == file.lastPathComponent }
        if existing { _ = try load(snapshot.sessionId) }
        guard existing || records.count < maximumSessions else { throw SessionStorageError.retentionLimit }
        let json = try codec.encodeSession(snapshot)
        let bytes = try JSONEncoder().encode(StoredEnvelope(version: 1, sessionJSON: json))
        guard bytes.count <= maximumBytes else { throw SessionStorageError.retentionLimit }

        // Reject rather than evict: no multi-file operation can remove a good session before a failed write.
        var remaining = maximumBytes - bytes.count
        for record in records where record.lastPathComponent != file.lastPathComponent {
            guard let size = try record.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= remaining else {
                throw SessionStorageError.retentionLimit
            }
            remaining -= size
        }
        try bytes.write(to: file, options: .atomic)
    }

    public func markDeliveryIncomplete(_ sessionID: String) throws {
        try save(load(sessionID).mergingDeliveryIncomplete(true))
    }

    func append(_ event: DiagnosticEvent) throws {
        let previous: SessionSnapshot?
        do { previous = try load(event.sessionId) } catch SessionStorageError.notFound { previous = nil }
        let snapshot = try SessionSnapshot(
            sessionId: event.sessionId, truncated: previous?.truncated ?? false,
            deliveryIncomplete: previous?.deliveryIncomplete, events: (previous?.events ?? []) + [event])
        try save(snapshot)
    }

    public func listSessions() throws -> [String] {
        try files().map { try loadFile($0).sessionId }.sorted()
    }

    public func load(_ sessionID: String) throws -> SessionSnapshot {
        let snapshot = try loadFile(url(for: sessionID))
        guard snapshot.sessionId == sessionID else { throw SessionStorageError.invalidStoredSession }
        return snapshot
    }

    public func export(_ sessionID: String) throws -> String { try codec.encodeSession(load(sessionID)) }

    public func delete(_ sessionID: String) throws {
        let file = url(for: sessionID)
        guard FileManager.default.fileExists(atPath: file.path) else { throw SessionStorageError.notFound }
        try FileManager.default.removeItem(at: file)
    }

    private func files() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: .skipsHiddenFiles
        ).filter {
            guard $0.pathExtension == "framewright" else { return false }
            let values = try $0.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            return values.isRegularFile == true && values.isSymbolicLink != true
        }
    }

    private func loadFile(_ file: URL) throws -> SessionSnapshot {
        guard FileManager.default.fileExists(atPath: file.path) else { throw SessionStorageError.notFound }
        let properties = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink != true else {
            throw SessionStorageError.invalidStoredSession
        }
        let data = try Data(contentsOf: file)
        let version = try JSONDecoder().decode(StoredVersion.self, from: data).version
        guard version == 1 else { throw SessionStorageError.unsupportedStoreVersion(version) }
        let envelope = try JSONDecoder().decode(StoredEnvelope.self, from: data)
        let snapshot = try codec.decodeSession(envelope.sessionJSON)
        guard url(for: snapshot.sessionId).lastPathComponent == file.lastPathComponent else {
            throw SessionStorageError.invalidStoredSession
        }
        return snapshot
    }

    private func url(for id: String) -> URL {
        // Fixed-size file name; do not put a raw session ID in the path.
        directory.appendingPathComponent(SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined())
            .appendingPathExtension("framewright")
    }
}

private struct StoredVersion: Decodable { let version: Int }
private struct StoredEnvelope: Codable {
    let version: Int
    let sessionJSON: String
}
