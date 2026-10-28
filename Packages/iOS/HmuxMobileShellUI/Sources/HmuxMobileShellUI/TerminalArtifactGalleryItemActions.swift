#if os(iOS)
import HmuxAgentChat
import HmuxAgentChatUI

struct TerminalArtifactGalleryItemActions {
    let loader: ChatArtifactLoader
    let open: (
        String,
        TerminalArtifactFilesSheet.Scope,
        ChatArtifactGallerySwipeOrder
    ) -> Void
    let copiedPath: () -> Void
}
#endif
