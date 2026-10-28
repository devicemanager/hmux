struct HostedInspectorDockControlScript {
    let allowSideDock: Bool
    let detachedFromHostWindow: Bool

    var source: String {
        let allowSideDockLiteral = allowSideDock ? "true" : "false"
        let detachedFromHostWindowLiteral = detachedFromHostWindow ? "true" : "false"
        return """
        (() => {
            if (typeof WI === "undefined")
                return null;
            const allowSideDock = \(allowSideDockLiteral);
            const detachedFromHostWindow = \(detachedFromHostWindowLiteral);
            function callOriginal(fn, event) {
                return typeof fn === "function" ? fn.call(WI, event) : null;
            }
            function installWrapper(methodName, originalName, wrapper) {
                if (typeof WI[originalName] !== "function") {
                    if (typeof WI[methodName] !== "function")
                        return false;
                    WI[originalName] = WI[methodName];
                }
                WI[methodName] = wrapper;
                return true;
            }
            function updateButton(button, hidden) {
                if (!button)
                    return;
                button.hidden = hidden;
                if (button.element) {
                    button.element.style.display = hidden ? "none" : "";
                    button.element.style.pointerEvents = hidden ? "none" : "";
                }
            }
            function updateButtons(buttons, hidden) {
                for (const button of buttons)
                    updateButton(button, hidden);
            }
            function dockMatches(enumValue, literal) {
                const configuration = WI.dockConfiguration;
                if (configuration === enumValue)
                    return true;
                return String(configuration).toLowerCase() === literal;
            }
            function enforceDockControls() {
                const disallowSideDock = !WI.__hmuxAllowSideDock;
                const dockConfiguration = WI.DockConfiguration || {};
                const dockedLeft = dockMatches(dockConfiguration.Left, "left");
                const dockedRight = dockMatches(dockConfiguration.Right, "right");
                const dockedBottom = !WI.__hmuxDetachedFromHostWindow &&
                    dockMatches(dockConfiguration.Bottom, "bottom");
                const detached = WI.__hmuxDetachedFromHostWindow ||
                    dockMatches(dockConfiguration.Detached, "detached") ||
                    dockMatches(dockConfiguration.Undocked, "undocked");
                updateButton(WI._dockLeftTabBarButton, disallowSideDock || (!detached && dockedLeft));
                updateButton(WI._dockRightTabBarButton, disallowSideDock || (!detached && dockedRight));
                updateButtons([
                    WI._dockBottomTabBarButton,
                    WI._dockBottomNavigationItem,
                    WI._dockBottomButton,
                ], !detached && dockedBottom);
                updateButtons([
                    WI._detachTabBarButton,
                    WI._detachNavigationItem,
                    WI._undockTabBarButton,
                    WI._undockButton,
                ], detached);
            }
            WI.__hmuxAllowSideDock = allowSideDock;
            WI.__hmuxDetachedFromHostWindow = detachedFromHostWindow;
            installWrapper("_dockLeft", "__hmuxOriginalDockLeft", function(event) {
                if (!WI.__hmuxAllowSideDock)
                    return callOriginal(WI._dockBottom, event);
                return callOriginal(WI.__hmuxOriginalDockLeft, event);
            });
            installWrapper("_dockRight", "__hmuxOriginalDockRight", function(event) {
                if (!WI.__hmuxAllowSideDock)
                    return callOriginal(WI._dockBottom, event);
                return callOriginal(WI.__hmuxOriginalDockRight, event);
            });
            installWrapper("_togglePreviousDockConfiguration", "__hmuxOriginalTogglePreviousDockConfiguration", function(event) {
                const dockConfiguration = WI.DockConfiguration || {};
                const previousSideDock = WI._previousDockConfiguration === dockConfiguration.Left ||
                    WI._previousDockConfiguration === dockConfiguration.Right;
                if (!WI.__hmuxAllowSideDock && previousSideDock)
                    return callOriginal(WI._dockBottom, event);
                return callOriginal(WI.__hmuxOriginalTogglePreviousDockConfiguration, event);
            });
            installWrapper("_updateDockNavigationItems", "__hmuxOriginalUpdateDockNavigationItems", function(...args) {
                if (typeof WI.__hmuxOriginalUpdateDockNavigationItems === "function")
                    WI.__hmuxOriginalUpdateDockNavigationItems.apply(WI, args);
                enforceDockControls();
            });
            if (typeof WI._updateDockNavigationItems === "function")
                WI._updateDockNavigationItems();
            else
                enforceDockControls();
            return WI.__hmuxAllowSideDock;
        })();
        """
    }
}
