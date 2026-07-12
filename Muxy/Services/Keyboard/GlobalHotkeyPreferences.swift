import Foundation

enum GlobalHotkeyTrigger: String, CaseIterable, Identifiable {
    case doubleCommand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doubleCommand:
            "Double Command"
        }
    }
}

enum GlobalHotkeyPreferences {
    static let enabledKey = "muxy.globalHotkey.enabled"
    static let triggerKey = "muxy.globalHotkey.trigger"
    static let doubleTapIntervalMillisecondsKey = "muxy.globalHotkey.doubleTapIntervalMilliseconds"
    static let toggleToHideKey = "muxy.globalHotkey.toggleToHide"

    static let defaultEnabled = true
    static let defaultTrigger = GlobalHotkeyTrigger.doubleCommand
    static let defaultDoubleTapIntervalMilliseconds = 300.0
    static let minimumDoubleTapIntervalMilliseconds = 100.0
    static let maximumDoubleTapIntervalMilliseconds = 1000.0
    static let doubleTapIntervalStepMilliseconds = 25.0
    static let defaultToggleToHide = true

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: enabledKey) != nil else { return defaultEnabled }
        return defaults.bool(forKey: enabledKey)
    }

    static func trigger(defaults: UserDefaults = .standard) -> GlobalHotkeyTrigger {
        guard let rawValue = defaults.string(forKey: triggerKey),
              let trigger = GlobalHotkeyTrigger(rawValue: rawValue)
        else { return defaultTrigger }
        return trigger
    }

    static func doubleTapIntervalMilliseconds(defaults: UserDefaults = .standard) -> Double {
        guard defaults.object(forKey: doubleTapIntervalMillisecondsKey) != nil else {
            return defaultDoubleTapIntervalMilliseconds
        }
        return clampedDoubleTapIntervalMilliseconds(defaults.double(forKey: doubleTapIntervalMillisecondsKey))
    }

    static func doubleTapInterval(defaults: UserDefaults = .standard) -> TimeInterval {
        doubleTapIntervalMilliseconds(defaults: defaults) / 1000
    }

    static func toggleToHide(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: toggleToHideKey) != nil else { return defaultToggleToHide }
        return defaults.bool(forKey: toggleToHideKey)
    }

    static func isAllowedDoubleTapIntervalMilliseconds(_ value: Double) -> Bool {
        (minimumDoubleTapIntervalMilliseconds ... maximumDoubleTapIntervalMilliseconds).contains(value)
    }

    static func clampedDoubleTapIntervalMilliseconds(_ value: Double) -> Double {
        min(max(value, minimumDoubleTapIntervalMilliseconds), maximumDoubleTapIntervalMilliseconds)
    }
}
