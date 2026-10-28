import Foundation

/// A deserialized hmux.json schema that validators share instead of re-parsing.
///
/// The tree is never mutated after parsing, so concurrent reads are safe.
struct HmuxParsedConfigSchema: @unchecked Sendable {
    /// The schema embedded in HmuxFoundation, parsed on first use.
    static let embedded = HmuxParsedConfigSchema(data: HmuxEmbeddedConfigSchema.data)

    let root: [String: Any]

    init(data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any] else {
            preconditionFailure("hmux.json schema is not a JSON object")
        }
        self.root = root
    }
}
