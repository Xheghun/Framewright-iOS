import Foundation

public enum CodecError: Error, Equatable, Sendable {
    case malformedJSON
    case unsupportedSchemaVersion(Int)
    case unknownEventType(String)
    case invalidPayload(String)
}

/// Encodes schema-v2 envelopes using Android-compatible field names and enum values.
/// Invalid input throws a typed CodecError. Unknown object fields are ignored.
public struct DiagnosticEventJSONCodec: Sendable {
    private struct Envelope: Codable {
        let schemaVersion: Int
        let event: DiagnosticEvent

        init(event: DiagnosticEvent) {
            schemaVersion = diagnosticSchemaVersion
            self.event = event
        }

        private enum CodingKeys: String, CodingKey { case schemaVersion, event }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            let version = try values.decode(Int.self, forKey: .schemaVersion)
            guard version == diagnosticSchemaVersion else { throw CodecError.unsupportedSchemaVersion(version) }
            schemaVersion = version
            event = try values.decode(DiagnosticEvent.self, forKey: .event)
        }
    }

    public init() {}

    public func encodeEvent(_ event: DiagnosticEvent) throws -> String { try encode(Envelope(event: event)) }
    public func decodeEvent(_ json: String) throws -> DiagnosticEvent {
        try decode(Envelope.self, from: json).event
    }
    public func encodeSession(_ snapshot: SessionSnapshot) throws -> String { try encode(snapshot) }
    public func decodeSession(_ json: String) throws -> SessionSnapshot { try decode(SessionSnapshot.self, from: json) }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(value), as: UTF8.self)
        } catch {
            throw CodecError.invalidPayload(String(describing: error))
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = Data(json.utf8)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as CodecError {
            throw error
        } catch {
            guard (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else {
                throw CodecError.malformedJSON
            }
            throw CodecError.invalidPayload(String(describing: error))
        }
    }
}
