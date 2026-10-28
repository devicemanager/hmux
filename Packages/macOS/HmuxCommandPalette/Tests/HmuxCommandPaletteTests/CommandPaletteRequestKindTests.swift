import Foundation
import Testing

@testable import HmuxCommandPalette

@Suite struct CommandPaletteRequestKindTests {
    @Test func notificationNamesMatchLegacyLiterals() {
        #expect(CommandPaletteRequestKind.commands.notificationName == "hmux.commandPaletteRequested")
        #expect(CommandPaletteRequestKind.agentInbox.notificationName == "hmux.agentInboxRequested")
        #expect(CommandPaletteRequestKind.switcher.notificationName == "hmux.commandPaletteSwitcherRequested")
        #expect(CommandPaletteRequestKind.renameTab.notificationName == "hmux.commandPaletteRenameTabRequested")
        #expect(CommandPaletteRequestKind.renameWorkspace.notificationName == "hmux.commandPaletteRenameWorkspaceRequested")
        #expect(
            CommandPaletteRequestKind.editWorkspaceDescription.notificationName
                == "hmux.commandPaletteEditWorkspaceDescriptionRequested"
        )
        #expect(CommandPaletteRequestKind.rename.notificationName == "hmux.commandPaletteRenameRequested")
    }

    @Test func everyKindMarksPending() {
        for kind in CommandPaletteRequestKind.allCases {
            #expect(kind.marksPending)
        }
    }

    @Test func notificationNamesAreDistinct() {
        let names = Set(CommandPaletteRequestKind.allCases.map(\.notificationName))
        #expect(names.count == CommandPaletteRequestKind.allCases.count)
    }
}
