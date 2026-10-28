import HmuxCloud
import HmuxAuthRuntime
import Foundation

extension BrowserPanel {
    static func remappedAppPricingSessionRestoreURL(_ url: URL?) -> URL? {
        guard let url, isAppPricingURL(url) else { return url }
        guard var components = URLComponents(url: AuthEnvironment.appPricingURL, resolvingAgainstBaseURL: false) else {
            return AuthEnvironment.appPricingURL
        }
        if let restoredComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = restoredComponents.queryItems
            components.fragment = restoredComponents.fragment
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "hmux_app" }
        queryItems.removeAll { $0.name == "hmux_scheme" }
        queryItems.append(URLQueryItem(name: "hmux_app", value: "1"))
        queryItems.append(URLQueryItem(name: "hmux_scheme", value: AuthEnvironment.callbackScheme))
        components.queryItems = queryItems
        return components.url ?? AuthEnvironment.appPricingURL
    }

    private static func isAppPricingURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return url.path == "/app-pricing"
    }
}
