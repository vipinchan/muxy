import Foundation
import Testing

@testable import Muxy

@Suite("Global hotkey JSON settings", .serialized)
@MainActor
struct GlobalHotkeySettingsJSONTests {
    @Test
    func settingsPersistThroughJSON() throws {
        let keys = [
            GlobalHotkeyPreferences.enabledKey,
            GlobalHotkeyPreferences.triggerKey,
            GlobalHotkeyPreferences.doubleTapIntervalMillisecondsKey,
            GlobalHotkeyPreferences.toggleToHideKey,
        ]
        let snapshot = GlobalHotkeySettingsJSONSnapshot.capture(keys: keys)
        defer { snapshot.restore() }

        try SettingsJSONStore.saveUserSettingsText("""
        {
          "\(GlobalHotkeyPreferences.enabledKey)": true,
          "\(GlobalHotkeyPreferences.triggerKey)": "doubleOption",
          "\(GlobalHotkeyPreferences.doubleTapIntervalMillisecondsKey)": 450,
          "\(GlobalHotkeyPreferences.toggleToHideKey)": false
        }
        """)

        #expect(GlobalHotkeyPreferences.isEnabled())
        #expect(GlobalHotkeyPreferences.trigger() == .doubleOption)
        #expect(GlobalHotkeyPreferences.doubleTapIntervalMilliseconds() == 450)
        #expect(!GlobalHotkeyPreferences.toggleToHide())
    }

    @Test
    func rejectsUnsupportedTrigger() throws {
        let snapshot = GlobalHotkeySettingsJSONSnapshot.capture(keys: [GlobalHotkeyPreferences.triggerKey])
        defer { snapshot.restore() }

        #expect(throws: SettingsJSONError.self) {
            try SettingsJSONStore.saveUserSettingsText("""
            {
              "\(GlobalHotkeyPreferences.triggerKey)": "unsupported"
            }
            """)
        }
    }

    @Test
    func rejectsOutOfRangeInterval() throws {
        let snapshot = GlobalHotkeySettingsJSONSnapshot.capture(
            keys: [GlobalHotkeyPreferences.doubleTapIntervalMillisecondsKey]
        )
        defer { snapshot.restore() }

        #expect(throws: SettingsJSONError.self) {
            try SettingsJSONStore.saveUserSettingsText("""
            {
              "\(GlobalHotkeyPreferences.doubleTapIntervalMillisecondsKey)": 5000
            }
            """)
        }
    }
}

private struct GlobalHotkeySettingsJSONSnapshot {
    let data: Data?
    let defaults: [String: Any]

    @MainActor
    static func capture(keys: [String]) -> GlobalHotkeySettingsJSONSnapshot {
        GlobalHotkeySettingsJSONSnapshot(
            data: try? Data(contentsOf: SettingsJSONStore.userSettingsURL),
            defaults: Dictionary(uniqueKeysWithValues: keys.map { key in
                (key, UserDefaults.standard.object(forKey: key) ?? NSNull())
            })
        )
    }

    @MainActor
    func restore() {
        if let data {
            try? data.write(to: SettingsJSONStore.userSettingsURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: SettingsJSONStore.userSettingsURL)
        }

        for (key, value) in defaults {
            if value is NSNull {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
    }
}
