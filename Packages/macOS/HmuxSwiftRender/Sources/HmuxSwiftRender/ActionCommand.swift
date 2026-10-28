/// A single command captured from a `Button`'s action closure.
///
/// The interpreter records the call shape; a host runtime executes it. The
/// `hmux` case maps onto hmux's socket command dispatcher (`method` + string
/// arguments), giving interpreted buttons the breadth of the hmux CLI.
public enum ActionCommand: Codable, Sendable, Equatable {
    /// A hmux command: a dispatcher method plus named string params, e.g.
    /// `hmux("workspace.select", workspace_id: w.id)` →
    /// `.hmux("workspace.select", ["workspace_id": "<uuid>"])`. Maps directly
    /// onto the socket command protocol (`{"method","params"}`).
    case hmux(method: String, params: [String: String])
    case log(String)
    /// Opens a URL (host runs it, e.g. via the workspace opener).
    case openURL(String)
}
