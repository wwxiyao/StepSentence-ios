import Foundation

struct SrtCue {
    let index: Int
    let startSec: Double
    let endSec: Double
    let text: String
}

enum SrtParseError: Error {
    case invalidFormat
}

enum SubtitleSegmenter {
    // Parse a standard .srt file into cues
    static func parse(url: URL) throws -> [SrtCue] {
        let data = try Data(contentsOf: url)
        guard let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw SrtParseError.invalidFormat
        }
        return parse(text: raw)
    }

    static func parse(text: String) -> [SrtCue] {
        // Normalize line endings
        let content = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var cues: [SrtCue] = []

        // Split by blank lines
        let blocks = content.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard lines.count >= 2 else { continue }
            let indexLine = lines[0].trimmingCharacters(in: .whitespaces)
            let timeLine = lines[1].trimmingCharacters(in: .whitespaces)
            guard let idx = Int(indexLine) else { continue }

            // be tolerant to spacing around '-->'
            let parts = timeLine.components(separatedBy: "-->")
            guard parts.count == 2 else { continue }
            let startStr = parts[0].trimmingCharacters(in: .whitespaces)
            let endStr = parts[1].trimmingCharacters(in: .whitespaces)
            guard let start = parseSrtTime(startStr), let end = parseSrtTime(endStr) else { continue }

            // Remaining lines are text; join with spaces
            let textLines = lines.dropFirst(2)
            let joined = textLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !joined.isEmpty else { continue }

            cues.append(SrtCue(index: idx, startSec: start, endSec: end, text: joined))
        }
        // Ensure in time order
        return cues.sorted { $0.startSec < $1.startSec }
    }

    static func parseSrtTime(_ s: String) -> Double? {
        // Format: HH:MM:SS,mmm
        let comps = s.split(separator: ":")
        guard comps.count == 3 else { return nil }
        let hour = Int(comps[0]) ?? 0
        let minute = Int(comps[1]) ?? 0
        let secMilli = comps[2].split(separator: ",")
        guard secMilli.count == 2 else { return nil }
        let second = Int(secMilli[0]) ?? 0
        let milli = Int(secMilli[1]) ?? 0
        let total = Double(hour * 3600 + minute * 60 + second) + Double(milli) / 1000.0
        return total
    }

    // Merge cues into semantic sentences using the "line-boundary-first" strategy
    // - Never split inside a cue even if it contains multiple sentences
    // - Merge consecutive cues until the cumulative text ends with a sentence-ending punctuation
    static func mergeCuesToSegments(_ cues: [SrtCue]) -> [(start: Double, end: Double, text: String, coveredIndices: [Int])] {
        var results: [(Double, Double, String, [Int])] = []
        var curStart: Double? = nil
        var curEnd: Double = 0
        var curText: [String] = []
        var curIndices: [Int] = []

        func flush() {
            guard let s = curStart, !curText.isEmpty else { return }
            let joined = curText.joined(separator: " ")
            results.append((s, curEnd, joined, curIndices))
            curStart = nil
            curEnd = 0
            curText.removeAll()
            curIndices.removeAll()
        }

        for cue in cues {
            if curStart == nil { curStart = cue.startSec }
            curEnd = cue.endSec
            curText.append(cue.text)
            curIndices.append(cue.index)

            if endsWithSentenceTerminator(cue.text) {
                // End segment only when the last cue ends with a sentence-terminator
                flush()
            }
        }
        // Flush remainder if any
        flush()
        return results
    }

    static func endsWithSentenceTerminator(_ s: String) -> Bool {
        // Trim trailing quotes or spaces
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove common trailing closing quotes/brackets
        let stripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\"'”’"))
        guard let last = stripped.unicodeScalars.last else { return false }
        // Sentence terminators set
        let terms = "。.!?！？…"
        return terms.unicodeScalars.contains(last)
    }
}
