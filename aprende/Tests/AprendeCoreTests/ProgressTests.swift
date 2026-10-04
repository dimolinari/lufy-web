import XCTest
@testable import AprendeCore

final class ProgressTests: XCTestCase {
    private let clock = DayClock.ecuador

    func testEcuadorDayBoundary() throws {
        let beforeMidnight = try date("2026-09-27T04:30:00Z")
        let afterMidnight = try date("2026-09-27T05:30:00Z")
        XCTAssertEqual(clock.day(for: beforeMidnight).iso, "2026-09-26")
        XCTAssertEqual(clock.day(for: afterMidnight).iso, "2026-09-27")
    }

    func testStreakContinuesBreaksAndIgnoresSameDay() throws {
        var streak = StreakState.empty
        let monday = CivilDay(year: 2026, month: 9, day: 7)
        streak = Streak.register(streak, on: monday, clock: clock)
        XCTAssertEqual(streak.current, 1)
        streak = Streak.register(streak, on: monday, clock: clock)
        XCTAssertEqual(streak.current, 1)
        let tuesday = clock.adding(days: 1, to: monday)
        streak = Streak.register(streak, on: tuesday, clock: clock)
        XCTAssertEqual(streak.current, 2)
        XCTAssertEqual(streak.best, 2)
        let friday = clock.adding(days: 3, to: tuesday)
        streak = Streak.register(streak, on: friday, clock: clock)
        XCTAssertEqual(streak.current, 1)
        XCTAssertEqual(streak.best, 2)
    }

    func testSpacedRepetitionIntervals() {
        let today = CivilDay(year: 2026, month: 9, day: 1)
        let missed = SpacedRepetition.next(card: nil, questionID: "q", correct: false, today: today, clock: clock)
        XCTAssertEqual(missed.intervalDays, 1)
        XCTAssertEqual(missed.repetitions, 0)
        XCTAssertEqual(missed.lapses, 1)
        XCTAssertEqual(missed.dueDay, "2026-09-02")
        XCTAssertEqual(missed.ease, 2.3, accuracy: 0.001)

        let first = SpacedRepetition.next(card: missed, questionID: "q", correct: true, today: CivilDay(iso: missed.dueDay)!, clock: clock)
        XCTAssertEqual(first.intervalDays, 1)
        XCTAssertEqual(first.repetitions, 1)

        let second = SpacedRepetition.next(card: first, questionID: "q", correct: true, today: CivilDay(iso: first.dueDay)!, clock: clock)
        XCTAssertEqual(second.intervalDays, 3)
        XCTAssertEqual(second.repetitions, 2)

        let third = SpacedRepetition.next(card: second, questionID: "q", correct: true, today: CivilDay(iso: second.dueDay)!, clock: clock)
        XCTAssertGreaterThan(third.intervalDays, 3)
        XCTAssertLessThanOrEqual(third.ease, SpacedRepetition.maximumEase)
    }

    func testPathUnlockPurchaseAndReviewQueue() throws {
        let catalog = try sampleCatalog()
        let engine = ProgressEngine(clock: clock)
        let day = try date("2026-09-10T15:00:00Z")
        var state = LearnerState.empty

        XCTAssertEqual(
            engine.availability(lessonID: "uno", catalog: catalog, state: state, entitlements: .freeOnly),
            .ready
        )
        XCTAssertEqual(
            engine.availability(lessonID: "dos", catalog: catalog, state: state, entitlements: .freeOnly),
            .lockedUntilPrevious
        )
        XCTAssertEqual(
            engine.availability(lessonID: "pago", catalog: catalog, state: state, entitlements: .freeOnly),
            .needsPurchase
        )
        XCTAssertEqual(
            engine.availability(lessonID: "pago", catalog: catalog, state: state, entitlements: Entitlements(premium: true)),
            .ready
        )

        XCTAssertThrowsError(
            try engine.submitLesson(
                state: state,
                catalog: catalog,
                lessonID: "dos",
                answers: correctAnswers(for: catalog.lesson(id: "dos")!.lesson),
                on: day,
                entitlements: .freeOnly
            )
        ) { error in
            XCTAssertEqual(error as? ProgressError, .lessonLocked)
        }

        var answers = correctAnswers(for: catalog.lesson(id: "uno")!.lesson)
        answers["uno-flag"] = .bool(true)
        answers["uno-choice"] = .option("a")
        let failed = try engine.submitLesson(
            state: state,
            catalog: catalog,
            lessonID: "uno",
            answers: answers,
            on: day,
            entitlements: .freeOnly
        )
        XCTAssertFalse(failed.1.passed)
        XCTAssertEqual(failed.1.xpAwarded, 0)
        XCTAssertEqual(failed.0.streak.current, 0)
        XCTAssertEqual(failed.0.reviews["uno-flag"]?.dueDay, "2026-09-11")
        state = failed.0

        let passed = try engine.submitLesson(
            state: state,
            catalog: catalog,
            lessonID: "uno",
            answers: correctAnswers(for: catalog.lesson(id: "uno")!.lesson),
            on: day,
            entitlements: .freeOnly
        )
        state = passed.0
        XCTAssertTrue(passed.1.passed)
        XCTAssertFalse(passed.1.alreadyPassed)
        XCTAssertEqual(passed.1.xpAwarded, 85)
        XCTAssertEqual(state.streak.current, 1)
        XCTAssertEqual(
            engine.availability(lessonID: "dos", catalog: catalog, state: state, entitlements: .freeOnly),
            .ready
        )
        XCTAssertEqual(state.reviews["uno-choice"]?.repetitions, 1)
        XCTAssertEqual(state.reviews["uno-flag"]?.repetitions, 1)

        let replay = try engine.submitLesson(
            state: state,
            catalog: catalog,
            lessonID: "uno",
            answers: correctAnswers(for: catalog.lesson(id: "uno")!.lesson),
            on: try date("2026-09-11T15:00:00Z"),
            entitlements: .freeOnly
        )
        XCTAssertTrue(replay.1.alreadyPassed)
        XCTAssertEqual(replay.1.xpAwarded, 0)
        XCTAssertEqual(replay.0.totalXP, 85)

        let dueTomorrow = engine.dueQuestions(state: state, catalog: catalog, on: try date("2026-09-11T15:00:00Z"))
        XCTAssertEqual(dueTomorrow.map(\.id), ["uno-choice", "uno-flag"])
        let notYet = engine.dueQuestions(state: state, catalog: catalog, on: day)
        XCTAssertTrue(notYet.isEmpty)

        let review = try engine.submitReview(
            state: state,
            catalog: catalog,
            questionID: "uno-flag",
            answer: .bool(false),
            on: try date("2026-09-11T15:00:00Z")
        )
        XCTAssertTrue(review.1.correct)
        XCTAssertEqual(review.1.xpAwarded, XPRules.reviewPoints)
        XCTAssertEqual(review.0.streak.current, 2)
    }

    func testPremiumCourseStaysClosedWithoutEntitlement() throws {
        let catalog = try sampleCatalog()
        let engine = ProgressEngine(clock: clock)
        XCTAssertThrowsError(
            try engine.submitLesson(
                state: .empty,
                catalog: catalog,
                lessonID: "pago",
                answers: correctAnswers(for: catalog.lesson(id: "pago")!.lesson),
                on: try date("2026-09-10T15:00:00Z"),
                entitlements: .freeOnly
            )
        ) { error in
            XCTAssertEqual(error as? ProgressError, .courseNeedsPurchase)
        }
    }

    private func date(_ iso: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try XCTUnwrap(formatter.date(from: iso))
    }

    private func correctAnswers(for lesson: Lesson) -> [String: SubmittedAnswer] {
        Dictionary(uniqueKeysWithValues: lesson.questions.map { ($0.id, $0.correctAnswer) })
    }

    private func sampleCatalog() throws -> Catalog {
        let free = Course(
            id: "gratis",
            title: "Gratis",
            summary: "Curso de prueba.",
            access: .free,
            units: [
                CourseUnit(
                    id: "unidad",
                    title: "Unidad",
                    summary: "Dos lecciones.",
                    lessons: [
                        lesson(id: "uno", choiceCorrect: "b", flag: false),
                        lesson(id: "dos", choiceCorrect: "a", flag: true),
                    ]
                )
            ]
        )
        let premium = Course(
            id: "extra",
            title: "Extra",
            summary: "Curso de pago.",
            access: .premium,
            units: [
                CourseUnit(
                    id: "extra-unidad",
                    title: "Extra",
                    summary: "Una lección.",
                    lessons: [lesson(id: "pago", choiceCorrect: "a", flag: true)]
                )
            ]
        )
        let catalog = Catalog(courses: [free, premium], planned: [])
        return catalog
    }

    private func lesson(id: String, choiceCorrect: String, flag: Bool) -> Lesson {
        let words = Array(repeating: "palabra", count: 500).joined(separator: " ")
        return Lesson(
            id: id,
            title: id,
            summary: "Resumen de prueba.",
            script: words + ".",
            sources: ["Fuente de prueba."],
            questions: [
                Question(
                    id: "\(id)-choice",
                    prompt: "Elige",
                    explanation: "opcion",
                    body: .multipleChoice(
                        options: [Choice(id: "a", text: "A"), Choice(id: "b", text: "B")],
                        correctOptionID: choiceCorrect
                    )
                ),
                Question(id: "\(id)-flag", prompt: "¿Falso?", explanation: "valor", body: .trueFalse(correct: flag)),
                Question(
                    id: "\(id)-order",
                    prompt: "Ordena",
                    explanation: "orden",
                    body: .order(
                        items: [Choice(id: "1", text: "Uno"), Choice(id: "2", text: "Dos")],
                        correctOrder: ["1", "2"]
                    )
                ),
                Question(
                    id: "\(id)-blank",
                    prompt: "Di ______",
                    explanation: "texto",
                    body: .fillBlank(acceptedAnswers: ["listo"])
                ),
            ]
        )
    }
}
