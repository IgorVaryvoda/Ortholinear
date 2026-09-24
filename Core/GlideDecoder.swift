import Foundation
import CoreGraphics

/// Decodes a glide (swipe) trace into ranked words, SHARK2-style.
///
/// Everything happens in "key space": x is divided by the key width and y by the row
/// pitch, so one unit is one key step in either direction even though keys are tall.
/// A word's template is the polyline through its key centers. Candidates are words whose
/// first and last keys lie near the trace ends and whose every key lies near the trace;
/// they are ranked by location distance, shape distance, an in-order key-pass check,
/// and the lexicon frequency prior.
struct GlideDecoder: Sendable {
    struct Candidate: Equatable, Sendable {
        var word: String
        var score: Double
    }

    struct Weights: Sendable {
        // Tuned on finger-like traces (jittered ends, cut corners, uneven sampling):
        // the elastic distance carries most of the weight, since real fingers rarely
        // pass through every key center at an even speed.
        /// Mean point-to-point distance between resampled trace and template, in keys.
        var location = 2.0
        /// Same, after normalizing translation and scale.
        var shape = 2.0
        /// Squared excess distance of template keys the trace does not pass, in order.
        var pass = 0.5
        /// Frequency prior, per 100 frequency points (the scale is already logarithmic).
        var frequency = 1.6
        /// Keys closer than this to the trace count as passed.
        var passTolerance = 0.5
        /// Elastic (DTW) distance between trace and template, in keys; tolerates corner cutting and speed changes.
        var elastic = 40.0
        /// Radius around the trace start and end for first and last letters.
        var endRadius = 1.5
        /// Every key of a candidate must lie this close to the trace.
        var nearRadius = 1.6
        /// Per natural-log unit of how often the word follows the previous words.
        var context = 0.6
    }

    static let learnedFrequency = 450
    private static let samples = 40
    private static let passSamples = 64

    let lexicon: SuggestionLexicon
    var weights = Weights()
    /// Letter → key index; several letters may share one key (г/ґ).
    private let keyIndex: [Unicode.Scalar: Int]
    /// Key centers in key space.
    private let keys: [SIMD2<Double>]
    private let scale: SIMD2<Double>

    init(lexicon: SuggestionLexicon, geometry: SuggestionGeometry) {
        self.lexicon = lexicon
        let ys = Set(geometry.centers.values.map { ($0.y * 2).rounded() / 2 }).sorted()
        let pitch = zip(ys, ys.dropFirst()).map { $1 - $0 }.filter { $0 > 1 }.min() ?? geometry.unit
        scale = SIMD2(1 / max(geometry.unit, 1), 1 / max(pitch, 1))
        var keyIndex: [Unicode.Scalar: Int] = [:], keys: [SIMD2<Double>] = []
        for (letter, center) in geometry.centers.sorted(by: { $0.key < $1.key }) {
            guard letter.unicodeScalars.count == 1, let scalar = letter.unicodeScalars.first else { continue }
            let point = SIMD2(Double(center.x), Double(center.y)) * scale
            if let existing = keys.firstIndex(of: point) { keyIndex[scalar] = existing; continue }
            keyIndex[scalar] = keys.count; keys.append(point)
        }
        self.keyIndex = keyIndex
        self.keys = keys
    }

    /// Key centers the finger passes for `word` (view coordinates), with repeated keys
    /// collapsed and apostrophes skipped; nil when a letter has no key.
    static func keyPath(_ word: String, geometry: SuggestionGeometry) -> [CGPoint]? {
        var path: [CGPoint] = []
        for ch in SuggestionText.normalize(word) {
            guard let center = geometry.centers[ch] else {
                if ch.isLetter { return nil }
                continue
            }
            if path.last != center { path.append(center) }
        }
        return path
    }

    func decode(_ points: [CGPoint], learned: [String] = [], following: [String: Int] = [:], limit: Int = 4) -> [String] {
        rank(points, learned: learned, following: following, limit: limit).map(\.word)
    }

    /// `following` holds how often each word follows the previous ones, from the context model.
    func rank(_ points: [CGPoint], learned: [String] = [], following: [String: Int] = [:], limit: Int = 4) -> [Candidate] {
        guard limit > 0, !keys.isEmpty else { return [] }
        var trace: [SIMD2<Double>] = []
        trace.reserveCapacity(points.count)
        for point in points {
            let p = SIMD2(Double(point.x), Double(point.y)) * scale
            guard p.x.isFinite, p.y.isFinite else { continue }
            if let last = trace.last, Self.length(p - last) < 1e-6 { continue }
            trace.append(p)
        }
        guard trace.count >= 2 else { return [] }
        let traceLength = Self.pathLength(trace)
        guard traceLength >= 0.25 else { return [] }

        var resampled: [SIMD2<Double>] = []
        Self.resample(trace, count: Self.samples, into: &resampled)
        let traceShape = Self.normalizedShape(resampled)
        var dense: [SIMD2<Double>] = []
        Self.resample(trace, count: Self.passSamples, into: &dense)
        let start = trace[0], end = trace[trace.count - 1]

        // Per key: pass penalty against each trace segment and the closest approach.
        let segments = dense.count - 1
        var passCost = [Double](repeating: 0, count: keys.count * segments)
        var nearest = [Double](repeating: .infinity, count: keys.count)
        for (k, key) in keys.enumerated() {
            for s in 0..<segments {
                let d = Self.distance(key, dense[s], dense[s + 1])
                nearest[k] = min(nearest[k], d)
                let excess = max(0, d - weights.passTolerance)
                passCost[k * segments + s] = excess * excess
            }
        }
        let nearTrace = nearest.map { $0 <= weights.nearRadius }
        let startKeys = Set(keys.indices.filter { Self.length(keys[$0] - start) <= weights.endRadius })
        let endKeys = Set(keys.indices.filter { Self.length(keys[$0] - end) <= weights.endRadius })
        guard !startKeys.isEmpty, !endKeys.isEmpty else { return [] }

        var path: [Int] = [], vertices: [SIMD2<Double>] = [], template: [SIMD2<Double>] = []
        var previous = [Double](repeating: 0, count: segments), current = previous
        var warp = [Double](repeating: 0, count: (Self.samples + 1) * 2)
        path.reserveCapacity(24); vertices.reserveCapacity(24); template.reserveCapacity(Self.samples)

        func score(_ word: String, frequency: Int) -> Double? {
            path.removeAll(keepingCapacity: true)
            for scalar in word.unicodeScalars {
                guard let k = keyIndex[scalar] else {
                    if scalar.properties.isAlphabetic { return nil }
                    continue
                }
                if path.last == k { continue }
                guard nearTrace[k] else { return nil }
                path.append(k)
            }
            guard path.count >= 2, let first = path.first, let last = path.last,
                  startKeys.contains(first), endKeys.contains(last) else { return nil }
            vertices.removeAll(keepingCapacity: true)
            for k in path { vertices.append(keys[k]) }
            let templateLength = Self.pathLength(vertices)
            guard templateLength <= traceLength * 2 + 1, templateLength >= traceLength * 0.5 - 1 else { return nil }

            // Every key must be passed near, in order: cheapest monotone assignment of keys to segments.
            for s in 0..<segments { previous[s] = 0 }
            for k in path {
                var best = Double.infinity
                let row = k * segments
                for s in 0..<segments {
                    best = min(best, previous[s])
                    current[s] = best + passCost[row + s]
                }
                swap(&previous, &current)
            }
            let pass = previous.min() ?? 0

            Self.resample(vertices, count: Self.samples, into: &template)
            var location = 0.0
            for i in 0..<Self.samples { location += Self.length(resampled[i] - template[i]) }
            location /= Double(Self.samples)
            let shape = Self.shapeDistance(traceShape, template)
            let elastic = weights.elastic > 0 ? Self.warpedDistance(resampled, template, cost: &warp) : 0
            return Double(frequency) / 100 * weights.frequency - location * weights.location
                - shape * weights.shape - pass * weights.pass - elastic * weights.elastic
        }

        var best: [String: Double] = [:]
        var visited = 0
        let prefixes = Set(keyIndex.filter { startKeys.contains($0.value) }.map(\.key))
        for prefix in prefixes {
            for id in lexicon.range(prefix: String(Character(prefix))) {
                visited += 1
                if visited & 255 == 0 && Task.isCancelled { return [] }
                let entry = lexicon.words[id]
                if var value = score(entry.word, frequency: entry.frequency) {
                    if let count = following[entry.word] { value += log1p(Double(count)) * weights.context }
                    best[entry.word] = max(best[entry.word] ?? -.infinity, value)
                }
            }
        }
        for word in learned {
            let normalized = SuggestionText.normalize(word)
            guard SuggestionText.isWord(normalized),
                  let value = score(normalized, frequency: Self.learnedFrequency) else { continue }
            best[normalized] = max(best[normalized] ?? -.infinity, value)
        }
        if Task.isCancelled { return [] }
        return best.map { Candidate(word: $0.key, score: $0.value) }
            .sorted { $0.score == $1.score ? $0.word < $1.word : $0.score > $1.score }
            .prefix(limit).map { $0 }
    }

    // MARK: - Geometry

    /// Mean distance along the cheapest monotone alignment of two equal-length point lists,
    /// within a band so one point can't absorb the whole other list.
    private static func warpedDistance(_ a: [SIMD2<Double>], _ b: [SIMD2<Double>], cost: inout [Double]) -> Double {
        let n = a.count, band = max(4, n / 5), width = n + 1
        for j in 0..<(2 * width) { cost[j] = .infinity }
        cost[0] = 0
        for i in 1...n {
            let row = (i & 1) * width, above = ((i - 1) & 1) * width
            for j in 0...n { cost[row + j] = .infinity }
            for j in max(1, i - band)...min(n, i + band) {
                let d = length(a[i - 1] - b[j - 1])
                cost[row + j] = d + min(cost[above + j - 1], cost[above + j], cost[row + j - 1])
            }
        }
        return cost[(n & 1) * width + n] / Double(2 * n)
    }

    private static func length(_ v: SIMD2<Double>) -> Double { (v * v).sum().squareRoot() }

    private static func pathLength(_ points: [SIMD2<Double>]) -> Double {
        var total = 0.0
        for i in 1..<max(points.count, 1) { total += length(points[i] - points[i - 1]) }
        return total
    }

    /// Distance from `p` to the segment `a`–`b`.
    private static func distance(_ p: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let ab = b - a, lengthSquared = (ab * ab).sum()
        guard lengthSquared > 0 else { return length(p - a) }
        let t = min(1, max(0, ((p - a) * ab).sum() / lengthSquared))
        return length(p - (a + ab * t))
    }

    /// `count` points equally spaced along the polyline.
    private static func resample(_ points: [SIMD2<Double>], count: Int, into out: inout [SIMD2<Double>]) {
        out.removeAll(keepingCapacity: true)
        guard let first = points.first, let last = points.last else { return }
        let total = pathLength(points)
        guard points.count > 1, total > 0, count > 1 else {
            out.append(contentsOf: repeatElement(first, count: max(count, 1))); return
        }
        let step = total / Double(count - 1)
        out.append(first)
        var segment = 0, covered = 0.0, segmentLength = length(points[1] - points[0])
        for i in 1..<(count - 1) {
            let target = step * Double(i)
            while segment < points.count - 2 && covered + segmentLength < target {
                covered += segmentLength; segment += 1
                segmentLength = length(points[segment + 1] - points[segment])
            }
            let t = segmentLength > 0 ? min(1, max(0, (target - covered) / segmentLength)) : 0
            out.append(points[segment] + (points[segment + 1] - points[segment]) * t)
        }
        out.append(last)
    }

    /// Centroid at the origin, larger bounding-box side of 1.
    private static func normalizedShape(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
        guard let first = points.first else { return [] }
        var low = first, high = first, sum = SIMD2<Double>(0, 0)
        for p in points { low = pointwiseMin(low, p); high = pointwiseMax(high, p); sum += p }
        let centroid = sum / Double(points.count), size = max(high.x - low.x, high.y - low.y)
        let factor = size > 1e-9 ? 1 / size : 1
        return points.map { ($0 - centroid) * factor }
    }

    private static func shapeDistance(_ trace: [SIMD2<Double>], _ template: [SIMD2<Double>]) -> Double {
        guard let first = template.first else { return 0 }
        var low = first, high = first, sum = SIMD2<Double>(0, 0)
        for p in template { low = pointwiseMin(low, p); high = pointwiseMax(high, p); sum += p }
        let centroid = sum / Double(template.count), size = max(high.x - low.x, high.y - low.y)
        let factor = size > 1e-9 ? 1 / size : 1
        var total = 0.0
        for i in template.indices { total += length(trace[i] - (template[i] - centroid) * factor) }
        return total / Double(template.count)
    }
}
