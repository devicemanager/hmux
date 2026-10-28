import HmuxFoundation

/// Keeps census identities attached to its immutable projection for later enrichment.
struct HmuxTopProcessCapture: Sendable {
    let listing: DarwinProcessListing
    let snapshot: HmuxTopProcessSnapshot
    let fields: HmuxTopProcessFields
}
