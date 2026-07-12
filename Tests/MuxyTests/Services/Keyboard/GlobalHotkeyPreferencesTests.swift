import Foundation
import Testing

@testable import Muxy

@Suite("GlobalHotkeyPreferences")
struct GlobalHotkeyPreferencesTests {
    @Test("defaults preserve current double command behavior")
    func defaultsPreserveCurrentBehavior() throws {
        let defaults = try #require(UserDefaults(suiteName: "GlobalHotkeyPreferencesTests.defaults"))
        defaults.removePersistentDomain(forName: "GlobalHotkeyPreferencesTests.defaults")
        defer { defaults.removePersistentDomain(forName: "GlobalHotkeyPreferencesTests.defaults") }

        #expect(GlobalHotkeyPreferences.isEnabled(defaults: defaults))
        #expect(GlobalHotkeyPreferences.trigger(defaults: defaults) == .doubleCommand)
        #expect(GlobalHotkeyPreferences.doubleTapIntervalMilliseconds(defaults: defaults) == 300)
        #expect(GlobalHotkeyPreferences.toggleToHide(defaults: defaults))
    }

    @Test(
        "supported modifier triggers round trip",
        arguments: [
            GlobalHotkeyTrigger.doubleCommand,
            GlobalHotkeyTrigger.doubleControl,
            GlobalHotkeyTrigger.doubleOption,
        ]
    )
    func supportedModifierTriggersRoundTrip(trigger: GlobalHotkeyTrigger) throws {
        let suiteName = "GlobalHotkeyPreferencesTests.trigger.\(trigger.rawValue)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(trigger.rawValue, forKey: GlobalHotkeyPreferences.triggerKey)

        #expect(GlobalHotkeyPreferences.trigger(defaults: defaults) == trigger)
    }

    @Test("invalid stored trigger falls back to double command")
    func invalidTriggerFallsBack() throws {
        let suiteName = "GlobalHotkeyPreferencesTests.trigger"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("unsupported", forKey: GlobalHotkeyPreferences.triggerKey)

        #expect(GlobalHotkeyPreferences.trigger(defaults: defaults) == .doubleCommand)
    }

    @Test("stored interval is clamped to supported range")
    func intervalIsClamped() throws {
        let suiteName = "GlobalHotkeyPreferencesTests.interval"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(50, forKey: GlobalHotkeyPreferences.doubleTapIntervalMillisecondsKey)
        #expect(
            GlobalHotkeyPreferences.doubleTapIntervalMilliseconds(defaults: defaults)
                == GlobalHotkeyPreferences.minimumDoubleTapIntervalMilliseconds
        )

        defaults.set(1500, forKey: GlobalHotkeyPreferences.doubleTapIntervalMillisecondsKey)
        #expect(
            GlobalHotkeyPreferences.doubleTapIntervalMilliseconds(defaults: defaults)
                == GlobalHotkeyPreferences.maximumDoubleTapIntervalMilliseconds
        )
    }
}
