import XCTest
import CoreGraphics
@testable import OrtholinearCore

/// Combinations a host or a stale state can put the keyboard in. A NaN frame or a missing
/// row would crash the extension rather than fail quietly.
final class EdgeCaseTests: XCTestCase {
    func testEveryPageLaysOutFiniteKeysAtAnyWidth() {
        let layer = CustomLayer(name: "Nav", rows: [[CustomKey("", command: .left)], [CustomKey("()", cursorBack: 1)], [CustomKey("x")]])
        let pages: [KeyboardPage] = [.letters, .numbers, .symbols, .layer(layer.id), .layer(UUID())]
        for page in pages {
            for digitAccess in DigitAccess.allCases {
                for placement in ShiftPlacement.allCases {
                    var preferences = KeyboardPreferences()
                    preferences.layers = [layer]
                    preferences.showLayerKey = true
                    preferences.digitAccess = digitAccess
                    preferences.shiftPlacement = placement
                    for language in KeyboardLanguage.allCases {
                        var state = InputState()
                        state.language = language
                        state.page = page
                        for width in [0.5, 1, 40, 320, 1366] {
                            for needsGlobe in [false, true] {
                                let cells = KeyboardGeometry.cells(width: width, state: state, preferences: preferences, needsGlobe: needsGlobe)
                                let context = "\(page) \(language) \(digitAccess) \(placement) \(width)"
                                XCTAssertFalse(cells.isEmpty, context)
                                for cell in cells {
                                    for frame in [cell.hitFrame, cell.visualFrame] {
                                        XCTAssertTrue([frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite), context)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        XCTAssertTrue(KeyboardGeometry.cells(width: 0, state: InputState(), preferences: .init(), needsGlobe: true).isEmpty)
    }

    func testPagesThatNoLongerExistLeadBackToNumbers() {
        var preferences = KeyboardPreferences()
        preferences.layers = [CustomLayer(name: "Nav", rows: [[CustomKey("a")], [CustomKey("b")], [CustomKey("c")]])]
        let gone = KeyboardPage.layer(UUID())
        XCTAssertEqual(KeyboardLayout.page(after: gone, preferences: preferences), .numbers)
        XCTAssertEqual(KeyboardLayout.page(after: .letters, preferences: preferences), .numbers)
        preferences.extrasEnabled = false
        XCTAssertEqual(KeyboardLayout.page(after: .layer(preferences.layers[0].id), preferences: preferences), .numbers)
        XCTAssertNil(KeyboardLayout.firstLayerPage(preferences))
    }
}
