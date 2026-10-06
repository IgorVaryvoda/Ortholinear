import XCTest
import CoreGraphics
@testable import OrtholinearCore

final class FlickTests: XCTestCase {
    private func cell(_ flicks: [FlickDirection: String], width: Double = 36, height: Double = 72) -> KeyCell {
        let frame = CGRect(x: 100, y: 100, width: width, height: height)
        return KeyCell(key: Key(action: .text("a"), flicks: flicks), hitFrame: frame, visualFrame: frame)
    }

    func testSwipesPickTheirDirection() {
        let key = cell([.up: "!", .down: "1", .left: "(", .right: ")"])
        let start = CGPoint(x: 118, y: 136)
        func flick(_ dx: Double, _ dy: Double) -> String? {
            KeyboardGeometry.flick(on: key, from: start, to: CGPoint(x: start.x + dx, y: start.y + dy))?.value
        }
        XCTAssertEqual(flick(0, -20), "!")
        XCTAssertEqual(flick(3, 25), "1")
        XCTAssertEqual(flick(-20, 4), "(")
        XCTAssertEqual(flick(22, -5), ")")
        XCTAssertNil(flick(10, -10), "Too short")
        XCTAssertNil(flick(30, -25), "Too diagonal")
        XCTAssertNil(flick(45, 0), "Far enough sideways to be a glide")
        XCTAssertNil(flick(0, 70), "A straight-down glide to the next row")
        XCTAssertNil(KeyboardGeometry.flick(on: cell([.up: "!"]), from: start, to: CGPoint(x: start.x, y: start.y + 25)),
                     "No flick set that way")
    }

    func testCustomFlicksNeedExtrasAndBeatDigits() {
        var layout = CustomLetterLayout(builtIn: .english)
        layout.rows[0][0].flicks = [.up: "!", .down: "§"]
        layout.rows[1][0].flicks = [.left: "toolong!!", .right: "a\nb", .up: "@"]
        var preferences = KeyboardPreferences(customLayouts: [.english: layout])
        var state = InputState(); state.language = .english
        let rows = KeyboardLayout.rows(state: state, needsGlobe: false, preferences: preferences)
        XCTAssertEqual(rows[0][0].flicks, [.up: "!", .down: "§"], "The person's down flick wins over the digit")
        XCTAssertEqual(rows[0][1].flicks, [.down: "2"])
        XCTAssertEqual(rows[1][0].flicks, [.up: "@"], "Long or multi-line flicks are ignored")

        preferences.extrasEnabled = false
        let plain = KeyboardLayout.rows(state: state, needsGlobe: false, preferences: preferences)
        XCTAssertEqual(plain[0][0].flicks, [.down: "1"], "Without extras, only the digit")
        XCTAssertEqual(plain[1][0].flicks, [:])

        var noLetter = layout
        noLetter.rows[0].remove(at: 0)
        noLetter.rows[1][0].flicks = [.up: "q"]
        XCTAssertTrue(noLetter.problems(for: .english).contains(.missingLetters("q")), "A flick never counts as reaching a letter")

        let saved = try? JSONDecoder().decode(CustomLetterLayout.self, from: JSONEncoder().encode(layout))
        XCTAssertEqual(saved, layout)
        let odd = try? JSONDecoder().decode(CustomKey.self, from: Data(#"{"output":"a","flicks":{"up":"!","sideways":"?"}}"#.utf8))
        XCTAssertEqual(odd?.flicks, [.up: "!"])
    }
}
