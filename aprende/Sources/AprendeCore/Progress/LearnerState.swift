import Foundation

public struct LearnerSettings: Codable, Equatable, Sendable {
    public var playbackSpeed: Double

    public static let speeds: [Double] = [0.75, 1, 1.25, 1.5, 1.75]

    public init(playbackSpeed: Double = 1) {
        self.playbackSpeed = Self.nearest(playbackSpeed)
    }

    public static func nearest(_ speed: Double) -> Double {
        speeds.min { abs($0 - speed) < abs($1 - speed) } ?? 1
    }
}

public struct LessonProgress: Codable, Equatable, Sendable {
    public var attempts: Int
    public var passed: Bool
    public var bestCorrect: Int
    public var total: Int
    public var lastPassedDay: String?

    public init(attempts: Int, passed: Bool, bestCorrect: Int, total: Int, lastPassedDay: String?) {
        self.attempts = attempts
        self.passed = passed
        self.bestCorrect = bestCorrect
        self.total = total
        self.lastPassedDay = lastPassedDay
    }
}

public struct LearnerState: Codable, Equatable, Sendable {
    public var totalXP: Int
    public var streak: StreakState
    public var settings: LearnerSettings
    public var lessons: [String: LessonProgress]
    public var reviews: [String: ReviewCard]
    public var acknowledgedNotices: [String]
    public var selectedDistrict: String?

    public init(
        totalXP: Int = 0,
        streak: StreakState = .empty,
        settings: LearnerSettings = LearnerSettings(),
        lessons: [String: LessonProgress] = [:],
        reviews: [String: ReviewCard] = [:],
        acknowledgedNotices: [String] = [],
        selectedDistrict: String? = nil
    ) {
        self.totalXP = totalXP
        self.streak = streak
        self.settings = settings
        self.lessons = lessons
        self.reviews = reviews
        self.acknowledgedNotices = acknowledgedNotices
        self.selectedDistrict = selectedDistrict
    }

    private enum CodingKeys: String, CodingKey {
        case totalXP, streak, settings, lessons, reviews, acknowledgedNotices, selectedDistrict
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalXP = try container.decode(Int.self, forKey: .totalXP)
        streak = try container.decode(StreakState.self, forKey: .streak)
        settings = try container.decode(LearnerSettings.self, forKey: .settings)
        lessons = try container.decode([String: LessonProgress].self, forKey: .lessons)
        reviews = try container.decode([String: ReviewCard].self, forKey: .reviews)
        acknowledgedNotices = try container.decodeIfPresent([String].self, forKey: .acknowledgedNotices) ?? []
        selectedDistrict = try container.decodeIfPresent(String.self, forKey: .selectedDistrict)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalXP, forKey: .totalXP)
        try container.encode(streak, forKey: .streak)
        try container.encode(settings, forKey: .settings)
        try container.encode(lessons, forKey: .lessons)
        try container.encode(reviews, forKey: .reviews)
        try container.encode(acknowledgedNotices, forKey: .acknowledgedNotices)
        try container.encodeIfPresent(selectedDistrict, forKey: .selectedDistrict)
    }

    public static let empty = LearnerState()
}

public enum LessonAvailability: Equatable, Sendable {
    case ready
    case completed
    case lockedUntilPrevious
    case needsPurchase
}

public struct QuestionGrade: Equatable, Sendable, Identifiable {
    public var id: String
    public var correct: Bool
    public var explanation: String

    public init(id: String, correct: Bool, explanation: String) {
        self.id = id
        self.correct = correct
        self.explanation = explanation
    }
}

public struct QuizOutcome: Equatable, Sendable {
    public var lessonID: String
    public var correctCount: Int
    public var total: Int
    public var passed: Bool
    public var xpAwarded: Int
    public var alreadyPassed: Bool
    public var grades: [QuestionGrade]

    public init(
        lessonID: String,
        correctCount: Int,
        total: Int,
        passed: Bool,
        xpAwarded: Int,
        alreadyPassed: Bool,
        grades: [QuestionGrade]
    ) {
        self.lessonID = lessonID
        self.correctCount = correctCount
        self.total = total
        self.passed = passed
        self.xpAwarded = xpAwarded
        self.alreadyPassed = alreadyPassed
        self.grades = grades
    }
}

public struct ReviewOutcome: Equatable, Sendable {
    public var questionID: String
    public var correct: Bool
    public var xpAwarded: Int
    public var explanation: String

    public init(questionID: String, correct: Bool, xpAwarded: Int, explanation: String) {
        self.questionID = questionID
        self.correct = correct
        self.xpAwarded = xpAwarded
        self.explanation = explanation
    }
}

public enum ProgressError: Error, Equatable {
    case unknownLesson(String)
    case lessonLocked
    case courseNeedsPurchase
    case missingAnswers([String])
    case unknownQuestion(String)
}

public struct ProgressEngine: Sendable {
    public var clock: DayClock

    public init(clock: DayClock = .ecuador) {
        self.clock = clock
    }

    public func availability(
        lessonID: String,
        catalog: Catalog,
        state: LearnerState,
        entitlements: Entitlements
    ) -> LessonAvailability {
        guard let found = catalog.lesson(id: lessonID) else {
            return .lockedUntilPrevious
        }
        if !entitlements.canOpen(found.course) {
            return .needsPurchase
        }
        let flat = found.course.lessonsInOrder
        if found.index > 0 {
            let previous = flat[found.index - 1]
            if state.lessons[previous.id]?.passed != true {
                return .lockedUntilPrevious
            }
        }
        if state.lessons[lessonID]?.passed == true {
            return .completed
        }
        return .ready
    }

    public func submitLesson(
        state: LearnerState,
        catalog: Catalog,
        lessonID: String,
        answers: [String: SubmittedAnswer],
        on date: Date,
        entitlements: Entitlements
    ) throws -> (LearnerState, QuizOutcome) {
        guard let found = catalog.lesson(id: lessonID) else {
            throw ProgressError.unknownLesson(lessonID)
        }
        switch availability(lessonID: lessonID, catalog: catalog, state: state, entitlements: entitlements) {
        case .needsPurchase:
            throw ProgressError.courseNeedsPurchase
        case .lockedUntilPrevious:
            throw ProgressError.lessonLocked
        case .ready, .completed:
            break
        }

        let questions = found.lesson.questions
        let missing = questions.map(\.id).filter { answers[$0] == nil }
        if !missing.isEmpty {
            throw ProgressError.missingAnswers(missing)
        }

        let grades = questions.map { question in
            QuestionGrade(
                id: question.id,
                correct: Scoring.isCorrect(question: question, answer: answers[question.id]!),
                explanation: question.explanation
            )
        }
        let correctCount = grades.filter(\.correct).count
        let total = questions.count
        let passed = XPRules.passed(correct: correctCount, total: total)
        let alreadyPassed = state.lessons[lessonID]?.passed == true
        let xp = XPRules.lessonAward(correct: correctCount, total: total, alreadyPassed: alreadyPassed)
        let today = clock.day(for: date)

        var updated = state
        updated.totalXP += xp
        var record = updated.lessons[lessonID] ?? LessonProgress(
            attempts: 0,
            passed: false,
            bestCorrect: 0,
            total: total,
            lastPassedDay: nil
        )
        record.attempts += 1
        record.total = total
        if correctCount >= record.bestCorrect {
            record.bestCorrect = correctCount
        }
        if passed {
            record.passed = true
            record.lastPassedDay = today.iso
            updated.streak = Streak.register(updated.streak, on: today, clock: clock)
        }
        updated.lessons[lessonID] = record
        updated.reviews = scheduleReviews(
            grades: grades,
            reviews: updated.reviews,
            today: today
        )

        let outcome = QuizOutcome(
            lessonID: lessonID,
            correctCount: correctCount,
            total: total,
            passed: passed,
            xpAwarded: xp,
            alreadyPassed: alreadyPassed,
            grades: grades
        )
        return (updated, outcome)
    }

    public func submitReview(
        state: LearnerState,
        catalog: Catalog,
        questionID: String,
        answer: SubmittedAnswer,
        on date: Date
    ) throws -> (LearnerState, ReviewOutcome) {
        guard let question = catalog.question(id: questionID) else {
            throw ProgressError.unknownQuestion(questionID)
        }
        let correct = Scoring.isCorrect(question: question, answer: answer)
        let today = clock.day(for: date)
        var updated = state
        updated.reviews[questionID] = SpacedRepetition.next(
            card: updated.reviews[questionID],
            questionID: questionID,
            correct: correct,
            today: today,
            clock: clock
        )
        let xp = correct ? XPRules.reviewPoints : 0
        updated.totalXP += xp
        if correct {
            updated.streak = Streak.register(updated.streak, on: today, clock: clock)
        }
        let outcome = ReviewOutcome(
            questionID: questionID,
            correct: correct,
            xpAwarded: xp,
            explanation: question.explanation
        )
        return (updated, outcome)
    }

    public func dueQuestions(state: LearnerState, catalog: Catalog, on date: Date) -> [Question] {
        let today = clock.day(for: date)
        let dueIDs = state.reviews.values
            .filter { SpacedRepetition.isDue($0, on: today) }
            .sorted { lhs, rhs in
                if lhs.dueDay == rhs.dueDay { return lhs.questionID < rhs.questionID }
                return lhs.dueDay < rhs.dueDay
            }
            .map(\.questionID)
        return dueIDs.compactMap { catalog.question(id: $0) }
    }

    private func scheduleReviews(
        grades: [QuestionGrade],
        reviews: [String: ReviewCard],
        today: CivilDay
    ) -> [String: ReviewCard] {
        var copy = reviews
        for grade in grades {
            let exists = copy[grade.id] != nil
            if grade.correct && !exists {
                continue
            }
            copy[grade.id] = SpacedRepetition.next(
                card: copy[grade.id],
                questionID: grade.id,
                correct: grade.correct,
                today: today,
                clock: clock
            )
        }
        return copy
    }
}
