# HmuxSidebarProviderKit

Internal app-side kit for hmux-owned sidebar providers.

Use this package for in-process sidebar render models, sidebar provider descriptors, and provider mutations that run inside the hmux app. It is not the public extension SDK for third-party sidebar app extensions, and all types use `HmuxSidebarProvider` naming to keep that boundary visible.

External extension authors should import `HmuxExtensionKit` instead.
