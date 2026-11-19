import Foundation

struct LyricLine: Equatable { let time: Double; let text: String }
func parseLRC(_ input: String) -> [LyricLine] {
    let regex = try! NSRegularExpression(pattern: #"\[(\d+):(\d{2})(?:[.:](\d{1,3}))?\]"#)
    let offsetRegex = try! NSRegularExpression(pattern: #"\[offset:([+-]?\d+)\]"#, options: .caseInsensitive)
    var offset = 0.0
    if let m = offsetRegex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)), let r = Range(m.range(at: 1), in: input) { offset = (Double(input[r]) ?? 0) / 1000 }
    var result: [LyricLine] = []
    for line in input.components(separatedBy: .newlines) {
        let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
        guard let last = matches.last, let end = Range(last.range, in: line)?.upperBound else { continue }
        let text = String(line[end...]).trimmingCharacters(in: .whitespaces)
        for m in matches {
            func value(_ i: Int) -> String { Range(m.range(at: i), in: line).map { String(line[$0]) } ?? "" }
            let fraction = value(3)
            let t = (Double(value(1)) ?? 0) * 60 + (Double(value(2)) ?? 0) + (Double(fraction) ?? 0) / pow(10, Double(fraction.count)) + offset
            result.append(LyricLine(time: t, text: text))
        }
    }
    return result.sorted { $0.time < $1.time }
}
func currentLyric(_ lines: [LyricLine], at time: Double) -> String? {
    lines.last(where: { $0.time <= time })?.text
}

// Consecutive line starts share one coordinate system: no reset at a timestamp.
func lyricStripOffset(lines: [LyricLine], starts: [Double], duration: Double, time: Double) -> Double {
    guard !lines.isEmpty, lines.count == starts.count else { return 0 }
    guard let i = lines.lastIndex(where: { $0.time <= time }) else { return starts[0] }
    let nextTime = i + 1 < lines.count ? lines[i + 1].time : max(duration, lines[i].time + 4)
    let nextStart = i + 1 < starts.count ? starts[i + 1] : starts[i] + 330
    let progress = min(1, max(0, (time - lines[i].time) / max(0.001, nextTime - lines[i].time)))
    return starts[i] + (nextStart - starts[i]) * progress
}

struct PlaybackClock {
    private var base = 0.0
    private var anchor = 0.0
    private var playing = false
    private var initialized = false
    func position(at now: Double) -> Double { base + (playing ? max(0, now - anchor) : 0) }
    mutating func update(position sample: Double, playing nextPlaying: Bool, now: Double) {
        let predicted = position(at: now)
        // Keep animation continuous between Music's coarse samples; snap on seeking.
        base = !initialized || abs(sample - predicted) > 1.2 || playing != nextPlaying ? sample : predicted
        anchor = now; playing = nextPlaying; initialized = true
    }
}


enum LyricDisplayMode: String {
    case scroll
    case jump
}
