import Foundation

public enum ContentError: Error, Equatable, CustomStringConvertible {
    case unreadable
    case invalid(String)

    public var description: String {
        switch self {
        case .unreadable:
            return "No se pudo leer el curso."
        case .invalid(let message):
            return message
        }
    }
}

public enum ContentLoader {
    public static func loadBundled() throws -> Catalog {
        guard let contentURL = Bundle.module.url(forResource: "Content", withExtension: nil) else {
            throw ContentError.invalid("No está la carpeta Content en el paquete.")
        }
        return try load(directory: contentURL)
    }

    public static func load(directory: URL) throws -> Catalog {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(ManifestFile.self, from: manifestData)
        var courses: [Course] = []
        for name in manifest.courses {
            let url = directory.appendingPathComponent(name)
            let data = try Data(contentsOf: url)
            let course = try JSONDecoder().decode(Course.self, from: data)
            courses.append(course)
        }
        let catalog = Catalog(courses: courses, planned: manifest.planned)
        try validate(catalog)
        return catalog
    }

    public static func validate(_ catalog: Catalog) throws {
        var courseIDs: Set<String> = []
        var lessonIDs: Set<String> = []
        var questionIDs: Set<String> = []
        if catalog.courses.isEmpty {
            throw ContentError.invalid("El catálogo no tiene cursos.")
        }
        for course in catalog.courses {
            try requireSlug(course.id, label: "curso")
            guard courseIDs.insert(course.id).inserted else {
                throw ContentError.invalid("Curso repetido: \(course.id)")
            }
            if course.units.isEmpty {
                throw ContentError.invalid("El curso \(course.id) no tiene unidades.")
            }
            for unit in course.units {
                try requireSlug(unit.id, label: "unidad")
                if unit.lessons.isEmpty {
                    throw ContentError.invalid("La unidad \(unit.id) no tiene lecciones.")
                }
                for lesson in unit.lessons {
                    try requireSlug(lesson.id, label: "lección")
                    guard lessonIDs.insert(lesson.id).inserted else {
                        throw ContentError.invalid("Lección repetida: \(lesson.id)")
                    }
                    if lesson.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        throw ContentError.invalid("La lección \(lesson.id) no tiene guion.")
                    }
                    if !Narration.isLessonLength(lesson.script) {
                        let minutes = Narration.minutes(for: lesson.script)
                        throw ContentError.invalid(
                            "La lección \(lesson.id) dura \(String(format: "%.1f", minutes)) min a \(Int(Narration.wordsPerMinute)) palabras por minuto. Tiene que quedar entre 3 y 6."
                        )
                    }
                    if lesson.questions.isEmpty {
                        throw ContentError.invalid("La lección \(lesson.id) no tiene preguntas.")
                    }
                    if lesson.sources.isEmpty {
                        throw ContentError.invalid("La lección \(lesson.id) no cita fuentes.")
                    }
                    for question in lesson.questions {
                        try requireSlug(question.id, label: "pregunta")
                        guard questionIDs.insert(question.id).inserted else {
                            throw ContentError.invalid("Pregunta repetida: \(question.id)")
                        }
                        try validate(question)
                    }
                }
            }
        }
        for planned in catalog.planned {
            try requireSlug(planned.id, label: "curso previsto")
            if courseIDs.contains(planned.id) {
                throw ContentError.invalid("El curso previsto \(planned.id) repite un curso publicado.")
            }
        }
    }

    private static func validate(_ question: Question) throws {
        if question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ContentError.invalid("La pregunta \(question.id) no tiene enunciado.")
        }
        switch question.body {
        case .multipleChoice(let options, let correctOptionID):
            if options.count < 2 {
                throw ContentError.invalid("La pregunta \(question.id) necesita al menos dos opciones.")
            }
            let ids = Set(options.map(\.id))
            if ids.count != options.count {
                throw ContentError.invalid("Opciones repetidas en \(question.id).")
            }
            if !ids.contains(correctOptionID) {
                throw ContentError.invalid("La respuesta de \(question.id) no está entre las opciones.")
            }
        case .trueFalse:
            break
        case .order(let items, let correctOrder):
            if items.count < 2 {
                throw ContentError.invalid("La pregunta \(question.id) necesita al menos dos hechos.")
            }
            let ids = items.map(\.id)
            if Set(ids).count != ids.count || Set(ids) != Set(correctOrder) || correctOrder.count != ids.count {
                throw ContentError.invalid("El orden de \(question.id) no es una permutación de sus hechos.")
            }
        case .fillBlank(let acceptedAnswers):
            if acceptedAnswers.allSatisfy({ AnswerNormalizer.normalize($0).isEmpty }) {
                throw ContentError.invalid("La pregunta \(question.id) no tiene respuestas aceptadas.")
            }
        }
    }

    private static func requireSlug(_ id: String, label: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        if id.isEmpty || id.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            throw ContentError.invalid("Identificador inválido para \(label): \(id)")
        }
    }
}

private struct ManifestFile: Codable {
    var courses: [String]
    var planned: [PlannedCourse]
}
