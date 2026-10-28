import ExtensionFoundation
import ExtensionKit
import Foundation
import SwiftUI

struct HmuxSidebarExtensionScene<Extension: HmuxSidebarExtension>: AppExtensionScene {
    private let sidebarExtension: Extension
    private let id: String

    init(_ extension: Extension, id: String = HmuxSidebarExtensionPoint.defaultSceneID) {
        self.sidebarExtension = `extension`
        self.id = id
    }

    @MainActor
    var body: PrimitiveAppExtensionScene {
        let runtime = HmuxSidebarExtensionRuntime(sidebarExtension: sidebarExtension)
        let acceptConnection: @Sendable (NSXPCConnection) -> Bool = { connection in
            runtime.accept(connection)
        }
        return PrimitiveAppExtensionScene(id: id) {
            sidebarExtension.body
        } onConnection: { connection in
            acceptConnection(connection)
        }
    }
}
