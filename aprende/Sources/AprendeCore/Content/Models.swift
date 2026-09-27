import Foundation

public enum CourseAccess: String, Codable, Equatable, Sendable {
    case free
    case premium
}

public struct Choice: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct Question: Equatable, Sendable, Identifiable {
    public var id: String
    public var prompt: String
    public var explanation: String
    public var body: Body

    public enum Body: Equatable, Sendable {
        case multipleChoice(options: [Choice], correctOptionID: String)
        case trueFalse(correct: Bool)
        case order(items: [Choice], correctOrder: [String])
        case fillBlank(acceptedAnswers: [String])
    }

    public init(id: String, prompt: String, explanation: String, body: Body) {
        self.id = id
        self.prompt = prompt
        self.explanation = explanation
        self.body = body
    }
}

public struct Lesson: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var script: String
    public var sources: [String]
    public var questions: [Question]
    public var figures: [LessonFigure]?

    public init(
        id: String,
        title: String,
        summary: String,
        script: String,
        sources: [String],
        questions: [Question],
        figures: [LessonFigure]? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.script = script
        self.sources = sources
        self.questions = questions
        self.figures = figures
    }

    public var resolvedFigures: [LessonFigure] {
        figures ?? []
    }

    public var estimatedMinutes: Int {
        max(1, Int(Narration.minutes(for: script).rounded()))
    }
}

public struct CourseUnit: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var lessons: [Lesson]

    public init(id: String, title: String, summary: String, lessons: [Lesson]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.lessons = lessons
    }
}

public struct Course: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var access: CourseAccess
    public var disclaimer: String?
    public var tool: String?
    public var offering: String?
    public var units: [CourseUnit]

    public init(
        id: String,
        title: String,
        summary: String,
        access: CourseAccess,
        disclaimer: String? = nil,
        tool: String? = nil,
        offering: String? = nil,
        units: [CourseUnit]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.access = access
        self.disclaimer = disclaimer
        self.tool = tool
        self.offering = offering
        self.units = units
    }

    public var lessonsInOrder: [Lesson] {
        units.flatMap(\.lessons)
    }

    public var offeringKind: CourseOffering {
        if let offering, let kind = CourseOffering(rawValue: offering) {
            return kind
        }
        return access == .premium ? .extra : .core
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, summary, access, disclaimer, tool, offering, units
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        access = try container.decode(CourseAccess.self, forKey: .access)
        disclaimer = try container.decodeIfPresent(String.self, forKey: .disclaimer)
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        offering = try container.decodeIfPresent(String.self, forKey: .offering)
        units = try container.decode([CourseUnit].self, forKey: .units)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(access, forKey: .access)
        try container.encodeIfPresent(disclaimer, forKey: .disclaimer)
        try container.encodeIfPresent(tool, forKey: .tool)
        try container.encodeIfPresent(offering, forKey: .offering)
        try container.encode(units, forKey: .units)
    }
}

public struct LessonFigure: Codable, Equatable, Sendable, Identifiable {
    public var kind: String
    public var ref: String

    public var id: String { "\(kind):\(ref)" }

    public init(kind: String, ref: String) {
        self.kind = kind
        self.ref = ref
    }
}

public struct PlannedCourse: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var access: CourseAccess
    public var offering: String?

    public init(id: String, title: String, summary: String, access: CourseAccess, offering: String? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.access = access
        self.offering = offering
    }

    public var offeringKind: CourseOffering {
        if let offering, let kind = CourseOffering(rawValue: offering) {
            return kind
        }
        return access == .premium ? .extra : .core
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, summary, access, offering
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        access = try container.decode(CourseAccess.self, forKey: .access)
        offering = try container.decodeIfPresent(String.self, forKey: .offering)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(access, forKey: .access)
        try container.encodeIfPresent(offering, forKey: .offering)
    }
}

public struct Catalog: Equatable, Sendable {
    public var courses: [Course]
    public var planned: [PlannedCourse]

    public init(courses: [Course], planned: [PlannedCourse]) {
        self.courses = courses
        self.planned = planned
    }

    public func course(id: String) -> Course? {
        courses.first { $0.id == id }
    }

    public func lesson(id: String) -> (course: Course, unit: CourseUnit, lesson: Lesson, index: Int)? {
        for course in courses {
            let flat = course.lessonsInOrder
            for (index, lesson) in flat.enumerated() where lesson.id == id {
                let unit = course.units.first { $0.lessons.contains { $0.id == id } }
                if let unit {
                    return (course, unit, lesson, index)
                }
            }
        }
        return nil
    }

    public func question(id: String) -> Question? {
        for course in courses {
            for lesson in course.lessonsInOrder {
                if let question = lesson.questions.first(where: { $0.id == id }) {
                    return question
                }
            }
        }
        return nil
    }

    public func nextLesson(after lessonID: String) -> Lesson? {
        guard let found = lesson(id: lessonID) else { return nil }
        let flat = found.course.lessonsInOrder
        let next = found.index + 1
        guard flat.indices.contains(next) else { return nil }
        return flat[next]
    }
}

public enum SubmittedAnswer: Equatable, Sendable {
    case option(String)
    case bool(Bool)
    case order([String])
    case text(String)
}

extension Question {
    public var correctAnswer: SubmittedAnswer {
        switch body {
        case .multipleChoice(_, let correctOptionID):
            return .option(correctOptionID)
        case .trueFalse(let correct):
            return .bool(correct)
        case .order(_, let correctOrder):
            return .order(correctOrder)
        case .fillBlank(let acceptedAnswers):
            return .text(acceptedAnswers.first ?? "")
        }
    }
}
