import Foundation

public struct ReviewCard: Codable, Equatable, Sendable, Identifiable {
    public var questionID: String
    public var ease: Double
    public var intervalDays: Int
    public var repetitions: Int
    public var dueDay: String
    public var lapses: Int

    public var id: String { questionID }

    public init(
        questionID: String,
        ease: Double,
        intervalDays: Int,
        repetitions: Int,
        dueDay: String,
        lapses: Int
    ) {
        self.questionID = questionID
        self.ease = ease
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.dueDay = dueDay
        self.lapses = lapses
    }
}

public enum SpacedRepetition {
    public static let initialEase = 2.5
    public static let minimumEase = 1.3
    public static let maximumEase = 2.8

    public static func next(
        card: ReviewCard?,
        questionID: String,
        correct: Bool,
        today: CivilDay,
        clock: DayClock
    ) -> ReviewCard {
        var ease = card?.ease ?? initialEase
        var interval = card?.intervalDays ?? 0
        var repetitions = card?.repetitions ?? 0
        var lapses = card?.lapses ?? 0

        if correct {
            if repetitions == 0 {
                interval = 1
            } else if repetitions == 1 {
                interval = 3
            } else {
                interval = max(1, Int((Double(interval) * ease).rounded()))
            }
            repetitions += 1
            ease = min(maximumEase, ease + 0.1)
        } else {
            repetitions = 0
            interval = 1
            ease = max(minimumEase, ease - 0.2)
            lapses += 1
        }

        let due = clock.adding(days: interval, to: today)
        return ReviewCard(
            questionID: questionID,
            ease: ease,
            intervalDays: interval,
            repetitions: repetitions,
            dueDay: due.iso,
            lapses: lapses
        )
    }

    public static func isDue(_ card: ReviewCard, on day: CivilDay) -> Bool {
        card.dueDay <= day.iso
    }
}
