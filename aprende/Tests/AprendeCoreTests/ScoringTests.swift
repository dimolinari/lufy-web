import XCTest
@testable import AprendeCore

final class ScoringTests: XCTestCase {
    func testNormalizerIgnoresCaseAccentsAndPunctuation() {
        XCTAssertEqual(AnswerNormalizer.normalize("  Dólar. "), "dolar")
        XCTAssertEqual(AnswerNormalizer.normalize("EL   dólar"), "el dolar")
        XCTAssertEqual(AnswerNormalizer.normalize("treinta"), "treinta")
    }

    func testMultipleChoiceTrueFalseOrderAndBlank() {
        let choice = Question(
            id: "q1",
            prompt: "¿Cuál?",
            explanation: "porque",
            body: .multipleChoice(
                options: [Choice(id: "a", text: "A"), Choice(id: "b", text: "B")],
                correctOptionID: "b"
            )
        )
        XCTAssertTrue(Scoring.isCorrect(question: choice, answer: .option("b")))
        XCTAssertFalse(Scoring.isCorrect(question: choice, answer: .option("a")))
        XCTAssertFalse(Scoring.isCorrect(question: choice, answer: .bool(true)))

        let flag = Question(id: "q2", prompt: "¿Sí?", explanation: "no", body: .trueFalse(correct: false))
        XCTAssertTrue(Scoring.isCorrect(question: flag, answer: .bool(false)))
        XCTAssertFalse(Scoring.isCorrect(question: flag, answer: .bool(true)))

        let order = Question(
            id: "q3",
            prompt: "Ordena",
            explanation: "así",
            body: .order(
                items: [Choice(id: "uno", text: "1"), Choice(id: "dos", text: "2")],
                correctOrder: ["uno", "dos"]
            )
        )
        XCTAssertTrue(Scoring.isCorrect(question: order, answer: .order(["uno", "dos"])))
        XCTAssertFalse(Scoring.isCorrect(question: order, answer: .order(["dos", "uno"])))

        let blank = Question(
            id: "q4",
            prompt: "El ______",
            explanation: "dolar",
            body: .fillBlank(acceptedAnswers: ["dólar"])
        )
        XCTAssertTrue(Scoring.isCorrect(question: blank, answer: .text("Dólar")))
        XCTAssertFalse(Scoring.isCorrect(question: blank, answer: .text("sucre")))
        XCTAssertFalse(Scoring.isCorrect(question: blank, answer: .text("   ")))
    }

    func testPassThresholdAndExperience() {
        XCTAssertFalse(XPRules.passed(correct: 2, total: 4))
        XCTAssertTrue(XPRules.passed(correct: 3, total: 4))
        XCTAssertEqual(XPRules.lessonAward(correct: 3, total: 4, alreadyPassed: false), 45)
        XCTAssertEqual(XPRules.lessonAward(correct: 4, total: 4, alreadyPassed: false), 85)
        XCTAssertEqual(XPRules.lessonAward(correct: 4, total: 4, alreadyPassed: true), 0)
        XCTAssertEqual(XPRules.lessonAward(correct: 2, total: 4, alreadyPassed: false), 0)
    }

    func testPlaybackSpeedSnapsToKnownValues() {
        XCTAssertEqual(LearnerSettings.nearest(1.1), 1)
        XCTAssertEqual(LearnerSettings.nearest(1.4), 1.5)
        XCTAssertEqual(LearnerSettings(playbackSpeed: 9).playbackSpeed, 1.75)
    }
}
