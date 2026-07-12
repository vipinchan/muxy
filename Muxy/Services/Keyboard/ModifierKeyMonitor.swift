import AppKit
import SwiftUI

struct DoubleCommandTapDetector {
    let doubleTapInterval: TimeInterval
    let maxTapDuration: TimeInterval

    private(set) var commandIsDown = false
    private(set) var commandDownTime: TimeInterval?
    private(set) var commandWasUsedWithKey = false
    private(set) var lastCommandTapTime: TimeInterval?

    init(
        doubleTapInterval: TimeInterval = 0.30,
        maxTapDuration: TimeInterval = 0.30
    ) {
        self.doubleTapInterval = doubleTapInterval
        self.maxTapDuration = maxTapDuration
    }

    mutating func handleFlagsChanged(commandPressed: Bool, at time: TimeInterval) -> Bool {
        if commandPressed, !commandIsDown {
            commandIsDown = true
            commandDownTime = time
            commandWasUsedWithKey = false
            return false
        }

        guard !commandPressed, commandIsDown else { return false }

        commandIsDown = false
        defer {
            commandDownTime = nil
            commandWasUsedWithKey = false
        }

        guard let commandDownTime,
              !commandWasUsedWithKey,
              time - commandDownTime <= maxTapDuration
        else {
            lastCommandTapTime = nil
            return false
        }

        if let lastCommandTapTime,
           time - lastCommandTapTime <= doubleTapInterval
        {
            self.lastCommandTapTime = nil
            return true
        }

        lastCommandTapTime = time
        return false
    }

    mutating func handleKeyDown() {
        guard commandIsDown else { return }
        commandWasUsedWithKey = true
        lastCommandTapTime = nil
    }

    mutating func reset() {
        commandIsDown = false
        commandDownTime = nil
        commandWasUsedWithKey = false
        lastCommandTapTime = nil
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
    private var hintTimer: Timer?
    private var doubleCommandDetector = DoubleCommandTapDetector()

    private static let hintDelay: TimeInterval = 0.5

    private init() {}

    func start() {
        guard localFlagsMonitor == nil, localKeyMonitor == nil, globalMonitor == nil else { return }

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
                self.doubleCommandDetector.handleKeyDown()
            }
            return event
        }

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
                    self.doubleCommandDetector.handleKeyDown()
                default:
                    break
                }
            }
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
                self.doubleCommandDetector.reset()
            }
        }
    }

    func stop() {
        if let localFlagsMonitor {
            NSEvent.removeMonitor(localFlagsMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        localFlagsMonitor = nil
        localKeyMonitor = nil
        globalMonitor = nil
        activationObserver = nil
        cancelHint()
        doubleCommandDetector.reset()
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
        let commandPressed = flags.contains(.command)
        guard doubleCommandDetector.handleFlagsChanged(commandPressed: commandPressed, at: time) else { return }
        toggleMuxyWindow()
    }

    private func toggleMuxyWindow() {
        if let window = AppDelegate.mainAppWindow(), NSApp.isActive, window.isKeyWindow {
            NSApp.hide(nil)
        } else {
            _ = AppDelegate.activateMainWindowOnCurrentSpace()
        }
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
