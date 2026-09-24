import XCTest
@testable import OrtholinearCore

/// Deterministic pseudo-random numbers for reproducible synthetic traces.
struct GlideRandom {
    var state: UInt64
    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func signed() -> Double { unit() * 2 - 1 }
}

enum GlideTraces {
    /// A straight polyline through the word's keys, sampled every 4 pt, with each corner
    /// displaced by up to `jitter` key widths and ±`noise` pt on every sample.
    static func make(_ word: String, geometry: SuggestionGeometry, random: inout GlideRandom,
                     jitter: Double = 0.3, noise: Double = 1.5) -> [CGPoint] {
        guard let path = GlideDecoder.keyPath(word, geometry: geometry), !path.isEmpty else { return [] }
        let offset = jitter * geometry.unit
        let corners = path.map { CGPoint(x: $0.x + random.signed() * offset, y: $0.y + random.signed() * offset) }
        var points = [corners[0]]
        for (a, b) in zip(corners, corners.dropFirst()) {
            let steps = max(1, Int((hypot(b.x - a.x, b.y - a.y) / 4).rounded(.up)))
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                let exact = step == steps
                points.append(CGPoint(x: a.x + (b.x - a.x) * t + (exact ? 0 : random.signed() * noise),
                                      y: a.y + (b.y - a.y) * t + (exact ? 0 : random.signed() * noise)))
            }
        }
        return points
    }

    /// The most frequent words of at least three letters that make a real glide.
    static func common(_ lexicon: SuggestionLexicon, geometry: SuggestionGeometry, count: Int) -> [String] {
        lexicon.words.sorted { $0.frequency == $1.frequency ? $0.word < $1.word : $0.frequency > $1.frequency }
            .lazy.map(\.word)
            .filter { $0.count >= 3 && (GlideDecoder.keyPath($0, geometry: geometry)?.count ?? 0) >= 2 }
            .prefix(count).map { $0 }
    }
}

enum HumanTraces {
    /// Finger-like: ends land anywhere in the key, corners are jittered and then cut by
    /// Chaikin smoothing, samples are uneven, and there is a little hand tremor.
    static func make(_ word: String, geometry: SuggestionGeometry, random: inout GlideRandom,
                     spread: Double = 0.4, cut: Int = 2) -> [CGPoint] {
        guard let path = GlideDecoder.keyPath(word, geometry: geometry), path.count >= 2 else { return [] }
        let ys = Set(geometry.centers.values.map(\.y)).sorted()
        let pitch = zip(ys, ys.dropFirst()).map { $1 - $0 }.filter { $0 > 1 }.min() ?? geometry.unit
        var corners = path.map { CGPoint(x: $0.x + random.signed() * spread * geometry.unit,
                                         y: $0.y + random.signed() * spread * 0.8 * pitch) }
        for _ in 0..<cut {
            var next = [corners[0]]
            for (a, b) in zip(corners, corners.dropFirst()) {
                next.append(CGPoint(x: a.x * 0.75 + b.x * 0.25, y: a.y * 0.75 + b.y * 0.25))
                next.append(CGPoint(x: a.x * 0.25 + b.x * 0.75, y: a.y * 0.25 + b.y * 0.75))
            }
            next.append(corners[corners.count - 1])
            corners = next
        }
        var points = [corners[0]]
        for (a, b) in zip(corners, corners.dropFirst()) {
            let steps = max(1, Int((hypot(b.x - a.x, b.y - a.y) / (3 + random.unit() * 9)).rounded(.up)))
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                points.append(CGPoint(x: a.x + (b.x - a.x) * t + random.signed() * 2, y: a.y + (b.y - a.y) * t + random.signed() * 2))
            }
        }
        return points
    }
}

final class GlideTests: XCTestCase {
    private static let engines: [KeyboardLanguage: SuggestionEngine] = {
        var result: [KeyboardLanguage: SuggestionEngine] = [:]
        for language in [KeyboardLanguage.english, .ukrainian] { result[language] = try? SuggestionResources.engine(language: language) }
        return result
    }()
    private func engine(_ language: KeyboardLanguage) throws -> SuggestionEngine {
        try XCTUnwrap(Self.engines[language])
    }
    private func geometry(_ language: KeyboardLanguage) -> SuggestionGeometry {
        SuggestionGeometry(language: language, preferences: KeyboardPreferences(), width: 393)
    }

    func testCommonWordAccuracy() throws {
        for (language, seed) in [(KeyboardLanguage.english, UInt64(7)), (.ukrainian, 11)] {
            let engine = try engine(language), geometry = geometry(language)
            let decoder = GlideDecoder(lexicon: engine.lexicon, geometry: geometry)
            let words = GlideTraces.common(engine.lexicon, geometry: geometry, count: 100)
            XCTAssertEqual(words.count, 100)
            var random = GlideRandom(state: seed), top1 = 0, top3 = 0, misses: [String] = []
            for word in words {
                let result = decoder.decode(GlideTraces.make(word, geometry: geometry, random: &random), limit: 3)
                if result.first == word { top1 += 1 } else { misses.append("\(word)→\(result.joined(separator: "/"))") }
                if result.contains(word) { top3 += 1 }
            }
            print("GLIDE_ACCURACY \(language.badge) top1=\(top1)/\(words.count) top3=\(top3)/\(words.count) misses: \(misses.joined(separator: ", "))")
            XCTAssertGreaterThanOrEqual(top1, 80, "\(language.badge) top-1")
            XCTAssertGreaterThanOrEqual(top3, 92, "\(language.badge) top-3")
        }
    }

    /// Real fingers land off-center, cut corners, and move unevenly, which straight
    /// synthetic traces never show. These floors guard the decoder against that.
    func testFingerLikeTraces() throws {
        for (language, floors) in [(KeyboardLanguage.english, (120, 100)), (.ukrainian, (130, 110))] {
            let engine = try engine(language), geometry = geometry(language)
            let decoder = GlideDecoder(lexicon: engine.lexicon, geometry: geometry)
            let sorted = engine.lexicon.words.sorted { $0.frequency > $1.frequency }.map(\.word)
                .filter { $0.count >= 2 && (GlideDecoder.keyPath($0, geometry: geometry)?.count ?? 0) >= 2 }
            let common = Array(sorted.prefix(150)), mid = stride(from: 150, to: 3000, by: 19).map { sorted[$0] }
            for (name, words, floor) in [("common", common, floors.0), ("mid", mid, floors.1)] {
                var random = GlideRandom(state: 42), top1 = 0
                for word in words where decoder.decode(HumanTraces.make(word, geometry: geometry, random: &random, cut: 1), limit: 1).first == word {
                    top1 += 1
                }
                print("GLIDE_FINGER \(language.badge) \(name) top1=\(top1)/\(words.count)")
                XCTAssertGreaterThanOrEqual(top1, floor, "\(language.badge) \(name)")
            }
        }
    }

    func testSentenceContextBreaksTies() throws {
        let engine = try engine(.english), geometry = geometry(.english)
        let decoder = GlideDecoder(lexicon: engine.lexicon, geometry: geometry)
        var random = GlideRandom(state: 3)
        let trace = GlideTraces.make("of", geometry: geometry, random: &random, jitter: 0, noise: 0)
        let plain = decoder.rank(trace, limit: 4)
        let boosted = decoder.rank(trace, following: ["off": 5000], limit: 4)
        XCTAssertEqual(boosted.first?.word, "off", "\(plain) → \(boosted)")
    }

    func testSpecificWords() throws {
        let cases: [(KeyboardLanguage, [String])] = [
            (.english, ["hello", "keyboard", "world", "thanks", "please", "because"]),
            (.ukrainian, ["привіт", "дякую", "клавіатура", "сьогодні", "будь", "завтра"])
        ]
        for (language, words) in cases {
            let engine = try engine(language), geometry = geometry(language)
            var random = GlideRandom(state: 42)
            for word in words where engine.lexicon.contains(word) {
                let trace = GlideTraces.make(word, geometry: geometry, random: &random)
                let result = engine.glide(trace, language: language, learned: [], geometry: geometry)
                XCTAssertTrue(result.prefix(3).contains { SuggestionText.normalize($0.word) == word }, "\(word): \(result.map(\.word))")
                XCTAssertTrue(result.allSatisfy { $0.kind == .correction })
            }
        }
    }

    func testCleanTraceIsTopChoice() throws {
        let engine = try engine(.english), geometry = geometry(.english)
        var random = GlideRandom(state: 1)
        let trace = GlideTraces.make("keyboard", geometry: geometry, random: &random, jitter: 0, noise: 0)
        XCTAssertEqual(engine.glide(trace, language: .english, learned: [], geometry: geometry).first?.word, "keyboard")
    }

    func testUkrainianApostropheIsCased() throws {
        let engine = try engine(.ukrainian), geometry = geometry(.ukrainian)
        XCTAssertTrue(engine.lexicon.contains("пам'ять"))
        var random = GlideRandom(state: 3)
        let trace = GlideTraces.make("пам'ять", geometry: geometry, random: &random)
        let result = engine.glide(trace, language: .ukrainian, learned: [], geometry: geometry)
        XCTAssertTrue(result.contains { $0.word == "памʼять" }, "\(result.map(\.word))")
    }

    func testTaughtWordsAreRecoverable() throws {
        let engine = try engine(.english), geometry = geometry(.english)
        var random = GlideRandom(state: 5)
        let trace = GlideTraces.make("zorblify", geometry: geometry, random: &random)
        XCTAssertFalse(engine.glide(trace, language: .english, learned: [], geometry: geometry).contains { $0.word == "zorblify" })
        let taught = engine.glide(trace, language: .english, learned: ["Zorblify"], geometry: geometry)
        XCTAssertEqual(taught.first?.word, "zorblify", "\(taught.map(\.word))")
        // Words of another language are never offered.
        XCTAssertFalse(engine.glide(trace, language: .english, learned: ["зорбліфай"], geometry: geometry).contains { $0.word == "зорбліфай" })
    }

    func testDegenerateTracesReturnNothing() throws {
        let engine = try engine(.english), geometry = geometry(.english)
        let h = try XCTUnwrap(geometry.centers["h"])
        XCTAssertTrue(engine.glide([], language: .english, learned: [], geometry: geometry).isEmpty)
        XCTAssertTrue(engine.glide([h], language: .english, learned: [], geometry: geometry).isEmpty)
        XCTAssertTrue(engine.glide([h, h, h], language: .english, learned: [], geometry: geometry).isEmpty)
        XCTAssertTrue(engine.glide([h, CGPoint(x: CGFloat.nan, y: CGFloat.nan)], language: .english, learned: [], geometry: geometry).isEmpty)
        XCTAssertTrue(engine.glide([h, try XCTUnwrap(geometry.centers["i"])], language: .english, learned: [],
                                   geometry: geometry, limit: 0).isEmpty)
    }

    func testLexiconPrefixRange() throws {
        let lexicon = try engine(.english).lexicon
        let range = lexicon.range(prefix: "key")
        XCTAssertFalse(range.isEmpty)
        XCTAssertTrue(range.allSatisfy { lexicon.words[$0].word.hasPrefix("key") })
        XCTAssertFalse(lexicon.words[range.lowerBound - 1].word.hasPrefix("key"))
        XCTAssertFalse(range.upperBound < lexicon.words.count && lexicon.words[range.upperBound].word.hasPrefix("key"))
        XCTAssertTrue(lexicon.range(prefix: "zzzzzz").isEmpty)
    }

    func testCancelledDecodeReturnsNothing() async throws {
        let engine = try engine(.english), geometry = geometry(.english)
        var random = GlideRandom(state: 9)
        let trace = GlideTraces.make("something", geometry: geometry, random: &random)
        let task = Task { () -> [WordSuggestion] in
            withUnsafeCurrentTask { $0?.cancel() }
            return engine.glide(trace, language: .english, learned: [], geometry: geometry)
        }
        let result = await task.value
        XCTAssertTrue(result.isEmpty)
    }

    func testDecodeTiming() throws {
        for language in [KeyboardLanguage.english, .ukrainian] {
            let engine = try engine(language), geometry = geometry(language)
            let words = GlideTraces.common(engine.lexicon, geometry: geometry, count: 40)
            var random = GlideRandom(state: 99)
            let traces = words.map { GlideTraces.make($0, geometry: geometry, random: &random) }
            let clock = ContinuousClock()
            var worst = Duration.zero
            let total = clock.measure {
                for trace in traces {
                    let elapsed = clock.measure { _ = engine.glide(trace, language: language, learned: [], geometry: geometry) }
                    worst = max(worst, elapsed)
                }
            }
            let average = total / traces.count
            let ms = { (d: Duration) in Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15 }
            print("GLIDE_TIMING \(language.badge) avg_ms=\(ms(average)) max_ms=\(ms(worst))")
            XCTAssertLessThan(ms(average), 250)
        }
    }
}
