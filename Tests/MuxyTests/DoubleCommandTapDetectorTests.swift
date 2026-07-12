import XCTest
@testable import Muxy

final class DoubleCommandTapDetectorTests: XCTestCase {
    func testDoubleTapWithinIntervalTriggers() {
        var detector = DoubleCommandTapDetector()

        XCTAssertFalse(detector.handleFlagsChanged(commandPressed: true, at: 1.00))
        XCTAssertFalse(detector.handleFlagsChanged(commandPressed: false, at: 1.05))
        XCTAssertFalse(detector.handleFlagsChanged(commandPressed: true, at: 1.20))
        XCTAssertTrue(detector.handleFlagsChanged(commandPressed: false, at: 1.25))
    }

    func testTapOutsideIntervalDoesNotTrigger() {
        var detector = DoubleCommandTapDetector()

        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.40)

        XCTAssertFalse(detector.handleFlagsChanged(commandPressed: false, at: 1.45))
    }

    func testCommandCombinationDoesNotCountAsTap() {
        var detector = DoubleCommandTapDetector()

        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        detector.handleKeyDown()
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.20)

        XCTAssertFalse(detector.handleFlagsChanged(commandPressed: false, at: 1.25))
    }

    func testLongPressDoesNotCountAsTap() {
        var detector = DoubleCommandTapDetector()

        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.40)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.50)

        XCTAssertFalse(detector.handleFlagsChanged(commandPressed: false, at: 1.55))
    }

    func testSingleTapDoesNotTrigger() {
        var detector = DoubleCommandTapDetector()

        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)

        XCTAssertFalse(detector.handleFlagsChanged(commandPressed: false, at: 1.05))
    }

    func testTriggerResetsState() {
        var detector = DoubleCommandTapDetector()

        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.20)
        XCTAssertTrue(detector.handleFlagsChanged(commandPressed: false, at: 1.25))

        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.30)
        XCTAssertFalse(detector.handleFlagsChanged(commandPressed: false, at: 1.35))
    }

    func testTripleTapOnlyTriggersOnce() {
        var detector = DoubleCommandTapDetector()

        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.00)
        _ = detector.handleFlagsChanged(commandPressed: false, at: 1.05)
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.10)
        XCTAssertTrue(detector.handleFlagsChanged(commandPressed: false, at: 1.15))
        _ = detector.handleFlagsChanged(commandPressed: true, at: 1.20)

        XCTAssertFalse(detector.handleFlagsChanged(commandPressed: false, at: 1.25))
    }
}
