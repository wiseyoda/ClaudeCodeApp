import XCTest
@testable import ClaudeCodeApp

final class SpecialKeyTests: XCTestCase {
    func testSpecialKeyControlSequences() {
        XCTAssertEqual(SpecialKey.ctrlC.sequence, "\u{03}")
        XCTAssertEqual(SpecialKey.ctrlD.sequence, "\u{04}")
        XCTAssertEqual(SpecialKey.ctrlZ.sequence, "\u{1A}")
        XCTAssertEqual(SpecialKey.ctrlL.sequence, "\u{0C}")
        XCTAssertEqual(SpecialKey.tab.sequence, "\t")
        XCTAssertEqual(SpecialKey.escape.sequence, "\u{1B}")
    }

    func testSpecialKeyArrowSequences() {
        XCTAssertEqual(SpecialKey.up.sequence, "\u{1B}[A")
        XCTAssertEqual(SpecialKey.down.sequence, "\u{1B}[B")
        XCTAssertEqual(SpecialKey.right.sequence, "\u{1B}[C")
        XCTAssertEqual(SpecialKey.left.sequence, "\u{1B}[D")
    }
}
