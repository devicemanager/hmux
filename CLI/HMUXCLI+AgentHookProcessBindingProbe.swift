extension HMUXCLI {
    enum AgentHookProcessBindingProbe {
        case notAttempted
        case unsupported
        case failed
        case resolved(CallerTerminalBinding)
    }
}
