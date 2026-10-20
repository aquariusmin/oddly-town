import Foundation

public enum LoadResult<Value> {
    case loaded(Value)
    case missing
    /// The file existed but couldn't be decoded. It was moved aside to `backupURL`.
    case recovered(backupURL: URL?)

    public var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

/// Small atomic JSON file store. Corrupt files are renamed, never silently overwritten,
/// so a bad write can be inspected and the app still starts.
public final class JSONFileStore<Value: Codable> {
    public let url: URL
    private let fileManager: FileManager

    public init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    public func load() -> LoadResult<Value> {
        guard let data = try? Data(contentsOf: url) else { return .missing }
        do {
            return .loaded(try Self.decoder.decode(Value.self, from: data))
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
            do {
                try fileManager.moveItem(at: url, to: backup)
                return .recovered(backupURL: backup)
            } catch {
                try? fileManager.removeItem(at: url)
                return .recovered(backupURL: nil)
            }
        }
    }

    public func load(default makeDefault: () -> Value) -> Value {
        load().value ?? makeDefault()
    }

    public func save(_ value: Value) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try Self.encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    public func delete() {
        try? fileManager.removeItem(at: url)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
