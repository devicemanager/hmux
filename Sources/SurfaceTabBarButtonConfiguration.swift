import HmuxSettings

struct SurfaceTabBarButtonConfiguration {
    let buttons: [HmuxSurfaceTabBarButton]
    let sourcePath: String?
    let globalConfigPath: String
    let settingPresets: [String: HmuxSettingValue]
    let terminalCommandSourcePaths: [String: String]
    let workspaceCommands: [String: HmuxResolvedCommand]
}
