import Foundation

@_spi(HmuxHostTransport) @objc public protocol HMUXSidebarHostXPC: NSObjectProtocol {
    func requestSidebarSnapshot(reply: @escaping (NSData?, NSString?) -> Void)
    func performSidebarAction(_ payload: NSData, reply: @escaping (NSData?, NSString?) -> Void)
}

@_spi(HmuxHostTransport) @objc public protocol HMUXSidebarExtensionXPC: NSObjectProtocol {
    @objc optional func requestExtensionManifest(reply: @escaping (NSData?, NSString?) -> Void)
    func sidebarSnapshotDidChange(_ payload: NSData)
}

@_spi(HmuxHostTransport)
public enum HmuxSidebarXPCCodec {
    public static let maximumSnapshotPayloadBytes = 512 * 1024
    public static let maximumManifestPayloadBytes = 64 * 1024
    public static let maximumActionPayloadBytes = 8 * 1024
    public static let maximumActionResultPayloadBytes = 8 * 1024

    public static func encodeSnapshot(_ snapshot: HmuxSidebarSnapshot) throws -> NSData {
        try encode(snapshot, kind: "snapshot", maximumBytes: maximumSnapshotPayloadBytes)
    }

    public static func decodeSnapshot(_ payload: NSData) throws -> HmuxSidebarSnapshot {
        try validatePayloadSize(payload, kind: "snapshot", maximumBytes: maximumSnapshotPayloadBytes)
        return try JSONDecoder().decode(HmuxSidebarSnapshot.self, from: payload as Data)
    }

    public static func encodeManifest(_ manifest: HmuxExtensionManifest) throws -> NSData {
        try encode(manifest, kind: "manifest", maximumBytes: maximumManifestPayloadBytes)
    }

    public static func decodeManifest(_ payload: NSData) throws -> HmuxExtensionManifest {
        try validatePayloadSize(payload, kind: "manifest", maximumBytes: maximumManifestPayloadBytes)
        return try JSONDecoder().decode(HmuxExtensionManifest.self, from: payload as Data)
    }

    public static func encodeAction(_ action: HmuxSidebarAction) throws -> NSData {
        try encode(action, kind: "action", maximumBytes: maximumActionPayloadBytes)
    }

    public static func decodeAction(_ payload: NSData) throws -> HmuxSidebarAction {
        try validatePayloadSize(payload, kind: "action", maximumBytes: maximumActionPayloadBytes)
        return try JSONDecoder().decode(HmuxSidebarAction.self, from: payload as Data)
    }

    public static func encodeActionResult(_ result: HmuxSidebarActionResult) throws -> NSData {
        try encode(result, kind: "actionResult", maximumBytes: maximumActionResultPayloadBytes)
    }

    public static func decodeActionResult(_ payload: NSData) throws -> HmuxSidebarActionResult {
        try validatePayloadSize(payload, kind: "actionResult", maximumBytes: maximumActionResultPayloadBytes)
        return try JSONDecoder().decode(HmuxSidebarActionResult.self, from: payload as Data)
    }

    private static func validatePayloadSize(_ payload: NSData, kind: String, maximumBytes: Int) throws {
        guard payload.length <= maximumBytes else {
            throw HmuxExtensionValidationError.payloadTooLarge(
                kind: kind,
                actualBytes: payload.length,
                maximumBytes: maximumBytes
            )
        }
    }

    private static func encode<T: Encodable>(_ value: T, kind: String, maximumBytes: Int) throws -> NSData {
        let payload = try JSONEncoder().encode(value) as NSData
        try validatePayloadSize(payload, kind: kind, maximumBytes: maximumBytes)
        return payload
    }
}
