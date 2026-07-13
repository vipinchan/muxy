import AppKit

@MainActor
enum ShortcutContext {
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("app.muxy.main-window")
    static let hotkeyWindowIdentifier = NSUserInterfaceItemIdentifier("app.muxy.hotkey-window")

    static func isMainWindow(_ window: NSWindow?) -> Bool {
        guard let identifier = window?.identifier else { return false }
        return identifier == mainWindowIdentifier || identifier == hotkeyWindowIdentifier
    }

    static func isHotkeyWindow(_ window: NSWindow?) -> Bool {
        window?.identifier == hotkeyWindowIdentifier
    }

    static func activeScopes(
        for window: NSWindow?,
        isTerminalFocused: Bool,
        isBrowserFocused: Bool = false
    ) -> Set<ShortcutScope> {
        guard isMainWindow(window) else { return [.global] }
        var scopes: Set<ShortcutScope> = [.global, .mainWindow]
        if isTerminalFocused {
            scopes.insert(.terminal)
        }
        if isBrowserFocused {
            scopes.insert(.browser)
        }
        return scopes
    }
}
