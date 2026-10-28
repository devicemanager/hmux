import Foundation
import HmuxBrowser

extension BrowserPanel {
    func configureMoveTabToNewWorkspaceContextMenu(for webView: HmuxWebView) {
        webView.contextMenuCanMoveTabToNewWorkspace = { [weak self] in
            guard let self,
                  let app = AppDelegate.shared,
                  let target = app.browserActionTarget(for: self) else {
                return false
            }
            return BrowserActionDispatcher(appDelegate: app)
                .canMoveBrowserToNewWorkspace(target: target)
        }
        webView.contextMenuMoveTabToNewWorkspace = { [weak self] in
            guard let self,
                  let app = AppDelegate.shared,
                  let target = app.browserActionTarget(for: self) else {
                return false
            }
            return BrowserActionDispatcher(appDelegate: app)
                .perform(.moveToNewWorkspace, on: target)
        }
    }
}
