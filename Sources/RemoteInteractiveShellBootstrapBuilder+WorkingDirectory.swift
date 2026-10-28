extension RemoteInteractiveShellBootstrapBuilder {
    static func remoteInitialWorkingDirectoryLines() -> [String] {
        [
            "hmux_remote_initial_cwd_b64='__HMUX_REMOTE_INITIAL_CWD_B64__'",
            "if [ \"$hmux_remote_initial_cwd_b64\" = '__HMUX_''REMOTE_INITIAL_CWD_B64__' ]; then hmux_remote_initial_cwd_b64=''; fi",
            "if [ -n \"$hmux_remote_initial_cwd_b64\" ]; then",
            "  hmux_remote_initial_cwd=\"$(printf %s \"$hmux_remote_initial_cwd_b64\" | base64 -d 2>/dev/null || printf %s \"$hmux_remote_initial_cwd_b64\" | base64 -D 2>/dev/null || true)\"",
            "  if [ -n \"$hmux_remote_initial_cwd\" ]; then cd \"$hmux_remote_initial_cwd\" 2>/dev/null || true; fi",
            "fi",
            "unset hmux_remote_initial_cwd_b64 hmux_remote_initial_cwd",
        ]
    }
}
