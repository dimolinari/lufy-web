import XCTest
@testable import AprendeCore

final class ContentTests: XCTestCase {
    func testBundledCourseIsOneUnitOfFiveLessons() throws {
        let catalog = try ContentLoader.loadBundled()
        let expected = [
            "ecuador-publico", "historia", "geografia", "provincias",
            "naturaleza", "cultura", "economia", "finanzas", "asamblea",
        ]
        XCTAssertEqual(catalog.courses.map(\.id), expected)
        let course = try XCTUnwrap(catalog.course(id: "ecuador-publico"))
        XCTAssertEqual(course.access, .free)
        XCTAssertEqual(course.units.count, 1)
        XCTAssertEqual(course.lessonsInOrder.count, 5)
        for other in catalog.courses where other.id != "ecuador-publico" {
            XCTAssertGreaterThanOrEqual(other.lessonsInOrder.count, 1, other.id)
        }
        let finance = try XCTUnwrap(catalog.course(id: "finanzas"))
        XCTAssertEqual(finance.disclaimer, StudyNotice.finance)
        XCTAssertEqual(finance.lessonsInOrder.count, 2)
        let assembly = try XCTUnwrap(catalog.course(id: "asamblea"))
        XCTAssertEqual(assembly.tool, AsambleaSchema.provinceTool)
        let figures = try FigureLibrary.loadBundled()
        try FigureLibrary.validate(catalog: catalog, library: figures)
        XCTAssertTrue(figures.datasets.contains { $0.id == "inflacion-anual" && $0.exampleData == false })
        XCTAssertEqual(figures.photos.count, 4)
        let kinds = course.lessonsInOrder.flatMap { lesson in
            lesson.questions.map { question -> String in
                switch question.body {
                case .multipleChoice: return "multipleChoice"
                case .trueFalse: return "trueFalse"
                case .order: return "order"
                case .fillBlank: return "fillBlank"
                }
            }
        }
        XCTAssertTrue(kinds.contains("multipleChoice"))
        XCTAssertTrue(kinds.contains("trueFalse"))
        XCTAssertTrue(kinds.contains("order"))
        XCTAssertTrue(kinds.contains("fillBlank"))
        for lesson in course.lessonsInOrder {
            XCTAssertTrue(Narration.isLessonLength(lesson.script), lesson.id)
            for question in lesson.questions {
                XCTAssertTrue(Scoring.isCorrect(question: question, answer: question.correctAnswer))
            }
        }
    }

    func testBundledCopyDoesNotCarryPersonalIdentifiers() throws {
        let catalog = try ContentLoader.loadBundled()
        let brand = try Brand.bundled()
        var corpus = [brand.appName, brand.bundleIdentifier, brand.elevenlabs.voiceId]
        for course in catalog.courses {
            corpus.append(course.title)
            corpus.append(course.summary)
            for lesson in course.lessonsInOrder {
                corpus.append(lesson.title)
                corpus.append(lesson.script)
                corpus.append(lesson.questions.map(\.prompt).joined(separator: "\n"))
                corpus.append(lesson.questions.map(\.explanation).joined(separator: "\n"))
                corpus.append(lesson.sources.joined(separator: "\n"))
            }
        }
        let text = corpus.joined(separator: "\n")
        XCTAssertNil(text.range(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.regularExpression, .caseInsensitive]))
        XCTAssertNil(text.range(of: #"\b\d{10}\b"#, options: .regularExpression))
    }

    func testBrandMatchesTheXcodeProject() throws {
        let brand = try Brand.bundled()
        XCTAssertTrue(brand.appName.localizedCaseInsensitiveContains("Lufy"))
        XCTAssertEqual(brand.elevenlabs.modelId, "eleven_v3")
        XCTAssertFalse(brand.bundleIdentifier.isEmpty)
        let project = try String(contentsOf: projectFile(), encoding: .utf8)
        XCTAssertTrue(project.contains("INFOPLIST_KEY_CFBundleDisplayName: \"\(brand.appName)\" # app-name"))
        XCTAssertTrue(project.contains("PRODUCT_BUNDLE_IDENTIFIER: \(brand.bundleIdentifier) # ios-bundle"))
        XCTAssertTrue(project.contains("PRODUCT_BUNDLE_IDENTIFIER: \(brand.macBundleIdentifier) # mac-bundle"))
        XCTAssertTrue(project.contains("DEVELOPMENT_TEAM: \(brand.developmentTeam) # team"))
    }

    func testSpeechTimelineSupportsSkip() {
        let script = "Uno dos tres cuatro. Cinco seis siete ocho. Nueve diez once doce."
        let timeline = SpeechTimeline.build(script: script, speed: 1)
        XCTAssertEqual(timeline.segments.count, 3)
        XCTAssertGreaterThan(timeline.duration, 0)
        let fast = SpeechTimeline.build(script: script, speed: 2)
        XCTAssertEqual(fast.duration, timeline.duration / 2, accuracy: 0.001)
        let later = timeline.text(from: timeline.segments[1].start)
        XCTAssertTrue(later.hasPrefix("Cinco"))
        XCTAssertFalse(later.contains("Uno dos"))
    }

    func testQuestionRoundTrip() throws {
        let question = Question(
            id: "vuelta",
            prompt: "¿Orden?",
            explanation: "así",
            body: .order(
                items: [Choice(id: "b", text: "B"), Choice(id: "a", text: "A")],
                correctOrder: ["a", "b"]
            )
        )
        let data = try JSONEncoder().encode(question)
        let decoded = try JSONDecoder().decode(Question.self, from: data)
        XCTAssertEqual(decoded, question)
    }

    private func projectFile() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("project.yml")
    }
}
