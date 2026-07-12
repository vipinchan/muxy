import AppKit
import SwiftUI

struct DoubleModifierTapDetector {
    let doubleTapInterval: TimeInterval
    let maxTapDuration: TimeInterval

    private(set) var modifierIsDown = false
    private(set) var modifierDownTime: TimeInterval?
    private(set) var modifierWasUsedWithKey = false
    private(set) var lastModifierTapTime: TimeInterval?

    init(
        doubleTapInterval: TimeInterval = 0.30,
        maxTapDuration: TimeInterval = 0.30
    ) {
        self.doubleTapInterval = doubleTapInterval
        self.maxTapDuration = maxTapDuration
    }

    mutating func handleFlagsChanged(modifierPressed: Bool, at time: TimeInterval) -> Bool {
        if modifierPressed, !modifierIsDown {
            modifierIsDown = true
            modifierDownTime = time
            modifierWasUsedWithKey = false
            return false
        }

        guard !modifierPressed, modifierIsDown else { return false }

        modifierIsDown = false
        defer {
            modifierDownTime = nil
            modifierWasUsedWithKey = false
        }

        guard let modifierDownTime,
              !modifierWasUsedWithKey,
              time - modifierDownTime <= maxTapDuration
        else {
            lastModifierTapTime = nil
            return false
        }

        if let lastModifierTapTime,
           time - lastModifierTapTime <= doubleTapInterval
        {
            self.lastModifierTapTime = nil
            return true
        }

        lastModifierTapTime = time
        return false
    }

    mutating func handleKeyDown() {
        guard modifierIsDown else { return }
        modifierWasUsedWithKey = true
        lastModifierTapTime = nil
    }

    mutating func reset() {
        modifierIsDown = false
        modifierDownTime = nil
        modifierWasUsedWithKey = false
        lastModifierTapTime = nil
    }
}

private extension GlobalHotkeyTrigger {
    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .doubleCommand:
            .command
        case .doubleControl:
            .control
        case .doubleOption:
            .option
        }
    }
}

private struct GlobalHotkeyConfiguration: Equatable {
    let isEnabled: Bool
    let trigger: GlobalHotkeyTrigger
    let doubleTapInterval: TimeInterval
    let toggleToHide: Bool

    static var current: GlobalHotkeyConfiguration {
        GlobalHotkeyConfiguration(
            isEnabled: GlobalHotkeyPreferences.isEnabled(),
            trigger: GlobalHotkeyPreferences.trigger(),
            doubleTapInterval: GlobalHotkeyPreferences.doubleTapInterval(),
            toggleToHide: GlobalHotkeyPreferences.toggleToHide()
        )
    }
}

@MainActor
@Observable
final class ModifierKeyMonitor {
    static let shared = ModifierKeyMonitor()

    private(set) var commandHeld = false
    private(set) var controlHeld = false
    private(set) var shiftHeld = false
    private(set) var optionHeld = false
    private(set) var showHints = false
    private var localFlagsMonitor: Any?
    private var localKeyMonitor: Any?
    private var globalMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var hintTimer: Timer?
    private var globalHotkeyConfiguration = GlobalHotkeyConfiguration.current
    private var doubleModifierDetector = DoubleModifierTapDetector(
        doubleTapInterval: GlobalHotkeyPreferences.doubleTapInterval()
    )

    private static let hintDelay: TimeInterval = 0.5

    private init() {}

    func start() {
        guard localFlagsMonitor == nil, localKeyMonitor == nil else { return }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let now = ProcessInfo.processInfo.systemUptime
            MainActor.assumeIsolated {
                self.handleFlagsChanged(flags, at: now)
            }
            return event
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            MainActor.assumeIsolated {
                self.handleKeyDown()
            }
            return event
        }

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                self.updateFlags(flags)
                self.doubleModifierDetector.reset()
            }
        }

        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshGlobalHotkeyConfiguration()
            }
        }

        refreshGlobalHotkeyConfiguration()
    }

    func stop() {
        if let localFlagsMonitor {
            NSEvent.removeMonitor(localFlagsMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        removeGlobalMonitor()
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        localFlagsMonitor = nil
        localKeyMonitor = nil
        activationObserver = nil
        settingsObserver = nil
        cancelHint()
        doubleModifierDetector.reset()
        HotkeyWindowController.shared.hide()
        commandHeld = false
        controlHeld = false
        shiftHeld = false
        optionHeld = false
    }

    func isHolding(modifiers: UInt) -> Bool {
        guard showHints else { return false }
        let flags = NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command), !commandHeld { return false }
        if flags.contains(.control), !controlHeld { return false }
        if flags.contains(.shift), !shiftHeld { return false }
        if flags.contains(.option), !optionHeld { return false }
        guard !flags.isEmpty else { return false }
        return true
    }

    func hint(for action: ShortcutAction) -> KeyCombo? {
        let combo = KeyBindingStore.shared.combo(for: action)
        guard isHolding(modifiers: combo.modifiers) else { return nil }
        return combo
    }

    private func handleFlagsChanged(_ flags: NSEvent.ModifierFlags, at time: TimeInterval) {
        updateFlags(flags)
        guard globalHotkeyConfiguration.isEnabled else {
            doubleModifierDetector.reset()
            return
        }

        let modifierPressed = flags.contains(globalHotkeyConfiguration.trigger.modifierFlag)
        guard doubleModifierDetector.handleFlagsChanged(modifierPressed: modifierPressed, at: time) else { return }
        if globalHotkeyConfiguration.toggleToHide {
            HotkeyWindowController.shared.toggle()
        } else {
            HotkeyWindowController.shared.show()
        }
    }

    private func handleKeyDown() {
        guard globalHotkeyConfiguration.isEnabled else { return }
        doubleModifierDetector.handleKeyDown()
    }

    private func refreshGlobalHotkeyConfiguration() {
        let newConfiguration = GlobalHotkeyConfiguration.current
        let monitorMatchesConfiguration = newConfiguration.isEnabled == (globalMonitor != nil)
        guard newConfiguration != globalHotkeyConfiguration || !monitorMatchesConfiguration else { return }

        let detectorConfigurationChanged = newConfiguration.isEnabled != globalHotkeyConfiguration.isEnabled
            || newConfiguration.trigger != globalHotkeyConfiguration.trigger
            || newConfiguration.doubleTapInterval != globalHotkeyConfiguration.doubleTapInterval

        globalHotkeyConfiguration = newConfiguration
        if detectorConfigurationChanged {
            doubleModifierDetector = DoubleModifierTapDetector(
                doubleTapInterval: newConfiguration.doubleTapInterval
            )
        }

        if newConfiguration.isEnabled {
            installGlobalMonitorIfNeeded()
            HotkeyWindowController.shared.prepareWhenMainWindowAvailable()
        } else {
            removeGlobalMonitor()
            doubleModifierDetector.reset()
            HotkeyWindowController.shared.hide()
        }
    }

    private func installGlobalMonitorIfNeeded() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            let eventType = event.type
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let now = ProcessInfo.processInfo.systemUptime
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch eventType {
                case .flagsChanged:
                    self.handleFlagsChanged(flags, at: now)
                case .keyDown:
                    self.handleKeyDown()
                default:
                    break
                }
            }
        }
    }

    private func removeGlobalMonitor() {
        guard let globalMonitor else { return }
        NSEvent.removeMonitor(globalMonitor)
        self.globalMonitor = nil
    }

    private func updateFlags(_ flags: NSEvent.ModifierFlags) {
        let wasHoldingModifier = commandHeld || controlHeld
        commandHeld = flags.contains(.command)
        controlHeld = flags.contains(.control)
        shiftHeld = flags.contains(.shift)
        optionHeld = flags.contains(.option)
        let isHoldingModifier = commandHeld || controlHeld
        if isHoldingModifier, !wasHoldingModifier {
            scheduleHint()
        } else if !isHoldingModifier {
            cancelHint()
        }
    }

    private func scheduleHint() {
        hintTimer?.invalidate()
        hintTimer = Timer.scheduledTimer(withTimeInterval: Self.hintDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.commandHeld || self.controlHeld else { return }
                self.showHints = true
            }
        }
    }

    private func cancelHint() {
        hintTimer?.invalidate()
        hintTimer = nil
        showHints = false
    }
}
