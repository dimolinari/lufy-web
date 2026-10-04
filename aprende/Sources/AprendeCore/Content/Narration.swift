import Foundation

public enum Narration {
    /// Ritmo de un narrador pausado, en palabras por minuto.
    public static let wordsPerMinute: Double = 140

    public static func wordCount(in script: String) -> Int {
        script.split { $0.isWhitespace }.count
    }

    public static func minutes(for script: String, speed: Double = 1) -> Double {
        let pace = wordsPerMinute * max(speed, 0.1)
        return Double(wordCount(in: script)) / pace
    }

    public static func isLessonLength(_ script: String) -> Bool {
        let minutes = minutes(for: script)
        return minutes >= 3 && minutes <= 6
    }
}

public struct SpeechSegment: Equatable, Sendable {
    public var text: String
    public var start: TimeInterval
    public var end: TimeInterval

    public init(text: String, start: TimeInterval, end: TimeInterval) {
        self.text = text
        self.start = start
        self.end = end
    }
}

/// Línea de tiempo estimada para la voz del dispositivo, cuando no hay MP3.
public struct SpeechTimeline: Equatable, Sendable {
    public var segments: [SpeechSegment]
    public var duration: TimeInterval

    public init(segments: [SpeechSegment], duration: TimeInterval) {
        self.segments = segments
        self.duration = duration
    }

    public static func build(script: String, speed: Double = 1) -> SpeechTimeline {
        let pieces = splitSentences(script)
        let pace = Narration.wordsPerMinute * max(speed, 0.1)
        var segments: [SpeechSegment] = []
        var cursor: TimeInterval = 0
        for piece in pieces {
            let words = Narration.wordCount(in: piece)
            let length = Double(words) / pace * 60
            let end = cursor + length
            segments.append(SpeechSegment(text: piece, start: cursor, end: end))
            cursor = end
        }
        return SpeechTimeline(segments: segments, duration: cursor)
    }

    public func segmentIndex(at time: TimeInterval) -> Int {
        guard !segments.isEmpty else { return 0 }
        let clamped = min(max(0, time), duration)
        if let index = segments.firstIndex(where: { clamped < $0.end }) {
            return index
        }
        return segments.count - 1
    }

    public func text(from time: TimeInterval) -> String {
        guard !segments.isEmpty else { return "" }
        let index = segmentIndex(at: time)
        return segments[index...].map(\.text).joined(separator: " ")
    }

    public func offset(at time: TimeInterval) -> TimeInterval {
        guard !segments.isEmpty else { return 0 }
        return segments[segmentIndex(at: time)].start
    }

    static func splitSentences(_ script: String) -> [String] {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var sentences: [String] = []
        var current = ""
        for character in trimmed {
            current.append(character)
            if character == "." || character == "!" || character == "?" || character == "…" {
                let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty {
                    sentences.append(piece)
                }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            sentences.append(tail)
        }
        return sentences
    }
}
