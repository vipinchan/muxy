import Testing

@testable import Muxy

@Suite("DoubleModifierTapDetector")
struct DoubleModifierTapDetectorTests {
    @Test("double tap within interval triggers")
    func doubleTapWithinIntervalTriggers() {
        var detector = DoubleModifierTapDetector()
        let firstDown = detector.handleFlagsChanged(modifierPressed: true, at: 1.00)
        let firstUp = detector.handleFlagsChanged(modifierPressed: false, at: 1.05)
        let secondDown = detector.handleFlagsChanged(modifierPressed: true, at: 1.20)
        let secondUp = detector.handleFlagsChanged(modifierPressed: false, at: 1.25)
        #expect(!firstDown)
        #expect(!firstUp)
        #expect(!secondDown)
        #expect(secondUp)
    }

    @Test("configured interval controls double tap recognition")
    func configuredIntervalControlsRecognition() {
        var detector = DoubleModifierTapDetector(doubleTapInterval: 0.50)
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(modifierPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.40)
        let result = detector.handleFlagsChanged(modifierPressed: false, at: 1.45)
        #expect(result)
    }

    @Test("tap outside interval does not trigger")
    func tapOutsideIntervalDoesNotTrigger() {
        var detector = DoubleModifierTapDetector()
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(modifierPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.40)
        let result = detector.handleFlagsChanged(modifierPressed: false, at: 1.45)
        #expect(!result)
    }

    @Test("modifier combination with a key does not count as tap")
    func modifierCombinationDoesNotCountAsTap() {
        var detector = DoubleModifierTapDetector()
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.00)
        detector.handleKeyDown()
        _ = detector.handleFlagsChanged(modifierPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.20)
        let result = detector.handleFlagsChanged(modifierPressed: false, at: 1.25)
        #expect(!result)
    }

    @Test("long press does not count as tap")
    func longPressDoesNotCountAsTap() {
        var detector = DoubleModifierTapDetector()
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(modifierPressed: false, at: 1.40)
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.50)
        let result = detector.handleFlagsChanged(modifierPressed: false, at: 1.55)
        #expect(!result)
    }

    @Test("single tap does not trigger")
    func singleTapDoesNotTrigger() {
        var detector = DoubleModifierTapDetector()
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.00)
        let result = detector.handleFlagsChanged(modifierPressed: false, at: 1.05)
        #expect(!result)
    }

    @Test("trigger resets state")
    func triggerResetsState() {
        var detector = DoubleModifierTapDetector()
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(modifierPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.20)
        let firstResult = detector.handleFlagsChanged(modifierPressed: false, at: 1.25)
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.30)
        let secondResult = detector.handleFlagsChanged(modifierPressed: false, at: 1.35)
        #expect(firstResult)
        #expect(!secondResult)
    }

    @Test("triple tap only triggers once")
    func tripleTapOnlyTriggersOnce() {
        var detector = DoubleModifierTapDetector()
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(modifierPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.10)
        let secondTapResult = detector.handleFlagsChanged(modifierPressed: false, at: 1.15)
        _ = detector.handleFlagsChanged(modifierPressed: true, at: 1.20)
        let thirdTapResult = detector.handleFlagsChanged(modifierPressed: false, at: 1.25)
        #expect(secondTapResult)
        #expect(!thirdTapResult)
    }
}
