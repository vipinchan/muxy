import Testing

@testable import Muxy

@Suite("DoubleCommandTapDetector")
struct DoubleCommandTapDetectorTests {
    @Test("double tap within interval triggers")
    func doubleTapWithinIntervalTriggers() {
        var detector = DoubleCommandTapDetector()
        #expect(!detector.handleFlagsChanged(commandPressed: true, at: 1.00))
        #expect(!detector.handleFlagsChanged(commandPressed: false, at: 1.05))
        #expect(!detector.handleFlagsChanged(commandPressed: true, at: 1.20))
        #expect(detector.handleFlagsChanged(commandPressed: false, at: 1.25))
    }

    @Test("tap outside interval does not trigger")
    func tapOutsideIntervalDoesNotTrigger() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.40)
        #expect(!detector.handleFlagsChanged(commandPressed: false, at: 1.45))
    }

    @Test("command combination does not count as tap")
    func commandCombinationDoesNotCountAsTap() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        detector.handleKeyDown()
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.20)
        #expect(!detector.handleFlagsChanged(commandPressed: false, at: 1.25))
    }

    @Test("long press does not count as tap")
    func longPressDoesNotCountAsTap() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.40)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.50)
        #expect(!detector.handleFlagsChanged(commandPressed: false, at: 1.55))
    }

    @Test("single tap does not trigger")
    func singleTapDoesNotTrigger() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        #expect(!detector.handleFlagsChanged(commandPressed: false, at: 1.05))
    }

    @Test("trigger resets state")
    func triggerResetsState() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.20)
        #expect(detector.handleFlagsChanged(commandPressed: false, at: 1.25))
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.30)
        #expect(!detector.handleFlagsChanged(commandPressed: false, at: 1.35))
    }

    @Test("triple tap only triggers once")
    func tripleTapOnlyTriggersOnce() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.10)
        #expect(detector.handleFlagsChanged(commandPressed: false, at: 1.15))
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.20)
        #expect(!detector.handleFlagsChanged(commandPressed: false, at: 1.25))
    }
}
