import Testing

@testable import Muxy

@Suite("DoubleCommandTapDetector")
struct DoubleCommandTapDetectorTests {
    @Test("double tap within interval triggers")
    func doubleTapWithinIntervalTriggers() {
        var detector = DoubleCommandTapDetector()
        let firstDown = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        let firstUp = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        let secondDown = detector.handleFlagsChanged(commandPressed: true, at: 1.20)
        let secondUp = detector.handleFlagsChanged(commandPressed: false, at: 1.25)
        #expect(!firstDown)
        #expect(!firstUp)
        #expect(!secondDown)
        #expect(secondUp)
    }

    @Test("tap outside interval does not trigger")
    func tapOutsideIntervalDoesNotTrigger() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.40)
        let result = detector.handleFlagsChanged(commandPressed: false, at: 1.45)
        #expect(!result)
    }

    @Test("command combination does not count as tap")
    func commandCombinationDoesNotCountAsTap() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        detector.handleKeyDown()
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.20)
        let result = detector.handleFlagsChanged(commandPressed: false, at: 1.25)
        #expect(!result)
    }

    @Test("long press does not count as tap")
    func longPressDoesNotCountAsTap() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.40)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.50)
        let result = detector.handleFlagsChanged(commandPressed: false, at: 1.55)
        #expect(!result)
    }

    @Test("single tap does not trigger")
    func singleTapDoesNotTrigger() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        let result = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        #expect(!result)
    }

    @Test("trigger resets state")
    func triggerResetsState() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.20)
        let firstResult = detector.handleFlagsChanged(commandPressed: false, at: 1.25)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.30)
        let secondResult = detector.handleFlagsChanged(commandPressed: false, at: 1.35)
        #expect(firstResult)
        #expect(!secondResult)
    }

    @Test("triple tap only triggers once")
    func tripleTapOnlyTriggersOnce() {
        var detector = DoubleCommandTapDetector()
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.10)
        let secondTapResult = detector.handleFlagsChanged(commandPressed: false, at: 1.15)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.20)
        let thirdTapResult = detector.handleFlagsChanged(commandPressed: false, at: 1.25)
        #expect(secondTapResult)
        #expect(!thirdTapResult)
    }
}
