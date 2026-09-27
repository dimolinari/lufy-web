import Foundation

public enum Scoring {
    public static func isCorrect(question: Question, answer: SubmittedAnswer) -> Bool {
        switch (question.body, answer) {
        case (.multipleChoice(_, let correctOptionID), .option(let chosen)):
            return chosen == correctOptionID
        case (.trueFalse(let correct), .bool(let chosen)):
            return chosen == correct
        case (.order(_, let correctOrder), .order(let chosen)):
            return chosen == correctOrder
        case (.fillBlank(let accepted), .text(let typed)):
            let normalized = AnswerNormalizer.normalize(typed)
            guard !normalized.isEmpty else { return false }
            return accepted.contains { AnswerNormalizer.normalize($0) == normalized }
        default:
            return false
        }
    }
}

public enum XPRules {
    public static let pointsPerCorrect = 15
    public static let perfectBonus = 25
    public static let reviewPoints = 5
    /// 3 de 4, o la misma proporción.
    public static let passingNumerator = 75
    public static let passingDenominator = 100

    public static func passed(correct: Int, total: Int) -> Bool {
        guard total > 0, correct >= 0 else { return false }
        return correct * passingDenominator >= passingNumerator * total
    }

    /// La primera vez que se aprueba la lección suma XP. Repetirla no vuelve a sumar.
    public static func lessonAward(correct: Int, total: Int, alreadyPassed: Bool) -> Int {
        guard passed(correct: correct, total: total), !alreadyPassed else { return 0 }
        var xp = correct * pointsPerCorrect
        if correct == total {
            xp += perfectBonus
        }
        return xp
    }
}
