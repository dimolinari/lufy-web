import Foundation

public enum StudyNotice {
    public static let finance = "finanzas"

    public static let financeBody = """
    Esto es educación, no una recomendación. Lufy no dice en qué ahorrar, qué comprar ni qué vender. Una acción, un bono o un índice se explican como ideas. Aquí no hay operaciones reales ni asesoría. Los gráficos de un país muestran la serie y la fuente que va debajo. Si un archivo dijera DATOS DE EJEMPLO, esos números no serían oficiales.
    """
}

public struct DataCitation: Codable, Equatable, Sendable {
    public var institution: String
    public var dataset: String
    public var date: String
    public var url: String

    public init(institution: String, dataset: String, date: String, url: String) {
        self.institution = institution
        self.dataset = dataset
        self.date = date
        self.url = url
    }
}

public struct YearPoint: Codable, Equatable, Sendable, Identifiable {
    public var year: Int
    public var value: Double

    public var id: Int { year }

    public init(year: Int, value: Double) {
        self.year = year
        self.value = value
    }
}

public struct MapPlace: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var region: String
    public var x: Double
    public var y: Double

    public init(id: String, name: String, region: String, x: Double, y: Double) {
        self.id = id
        self.name = name
        self.region = region
        self.x = x
        self.y = y
    }
}

public struct StudyDataset: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var kind: String
    public var unit: String
    public var decimals: Int
    public var exampleData: Bool
    public var diagram: Bool
    public var note: String
    public var source: DataCitation
    public var points: [YearPoint]
    public var places: [MapPlace]

    public init(
        id: String,
        title: String,
        kind: String,
        unit: String,
        decimals: Int,
        exampleData: Bool,
        diagram: Bool,
        note: String,
        source: DataCitation,
        points: [YearPoint] = [],
        places: [MapPlace] = []
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.unit = unit
        self.decimals = decimals
        self.exampleData = exampleData
        self.diagram = diagram
        self.note = note
        self.source = source
        self.points = points
        self.places = places
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, kind, unit, decimals, exampleData, diagram, note, source, points, places
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        kind = try container.decode(String.self, forKey: .kind)
        unit = try container.decode(String.self, forKey: .unit)
        decimals = try container.decode(Int.self, forKey: .decimals)
        exampleData = try container.decode(Bool.self, forKey: .exampleData)
        diagram = try container.decodeIfPresent(Bool.self, forKey: .diagram) ?? false
        note = try container.decode(String.self, forKey: .note)
        source = try container.decode(DataCitation.self, forKey: .source)
        points = try container.decodeIfPresent([YearPoint].self, forKey: .points) ?? []
        places = try container.decodeIfPresent([MapPlace].self, forKey: .places) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(kind, forKey: .kind)
        try container.encode(unit, forKey: .unit)
        try container.encode(decimals, forKey: .decimals)
        try container.encode(exampleData, forKey: .exampleData)
        try container.encode(diagram, forKey: .diagram)
        try container.encode(note, forKey: .note)
        try container.encode(source, forKey: .source)
        try container.encode(points, forKey: .points)
        try container.encode(places, forKey: .places)
    }
}

public struct PhotoCredit: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var file: String
    public var title: String
    public var author: String
    public var license: String
    public var licenseURL: String
    public var sourceURL: String

    public init(
        id: String,
        file: String,
        title: String,
        author: String,
        license: String,
        licenseURL: String,
        sourceURL: String
    ) {
        self.id = id
        self.file = file
        self.title = title
        self.author = author
        self.license = license
        self.licenseURL = licenseURL
        self.sourceURL = sourceURL
    }
}

public struct StudyLibrary: Equatable, Sendable {
    public var datasets: [StudyDataset]
    public var photos: [PhotoCredit]
    public var mediaDirectory: URL?

    public init(datasets: [StudyDataset], photos: [PhotoCredit], mediaDirectory: URL?) {
        self.datasets = datasets
        self.photos = photos
        self.mediaDirectory = mediaDirectory
    }

    public func dataset(id: String) -> StudyDataset? {
        datasets.first { $0.id == id }
    }

    public func photo(id: String) -> PhotoCredit? {
        photos.first { $0.id == id }
    }

    public func photoURL(_ credit: PhotoCredit) -> URL? {
        mediaDirectory?.appendingPathComponent(credit.file)
    }
}

public enum DataCaution {
    public static let exampleBanner = "DATOS DE EJEMPLO"

    public static func caption(_ dataset: StudyDataset) -> String {
        let source = "\(dataset.source.institution). \(dataset.source.dataset). \(dataset.source.date)."
        if dataset.exampleData {
            return "\(exampleBanner). Estos números no son una serie oficial. \(source)"
        }
        if dataset.diagram {
            return "Esquema didáctico, no un mapa oficial. \(source)"
        }
        return source
    }
}

public enum ChartProbe {
    public static func index(at fraction: Double, count: Int) -> Int {
        guard count > 0 else { return 0 }
        if count == 1 { return 0 }
        let clamped = min(max(fraction, 0), 1)
        return Int((clamped * Double(count - 1)).rounded())
    }
}

public enum ChartFormat {
    public static func spanish(_ value: Double, decimals: Int) -> String {
        let places = max(0, decimals)
        let sign = value < 0 ? "-" : ""
        let factor = pow(10, Double(places))
        let scaled = (abs(value) * factor).rounded() / factor
        let whole = Int(scaled)
        if places == 0 {
            return sign + String(whole)
        }
        let fraction = Int((scaled - Double(whole)) * factor + 0.5)
        let digits = String(format: "%0\(places)d", fraction)
        return "\(sign)\(whole),\(digits)"
    }
}

public struct BalancePoint: Equatable, Sendable, Identifiable {
    public var year: Int
    public var value: Double

    public var id: Int { year }

    public init(year: Int, value: Double) {
        self.year = year
        self.value = value
    }
}

public enum CompoundInterest {
    public static let calculatorID = "interes-compuesto"

    /// `annualRate` es decimal: 0,05 es cinco por ciento al año.
    /// El aporte entra al final de cada mes, después del interés de ese mes.
    public static func balances(
        principal: Double,
        annualRate: Double,
        years: Int,
        monthlyContribution: Double
    ) -> [BalancePoint] {
        let span = max(0, years)
        var balance = principal
        var points = [BalancePoint(year: 0, value: balance)]
        guard span > 0 else { return points }
        let monthlyRate = annualRate / 12.0
        for year in 1...span {
            for _ in 0..<12 {
                balance = balance * (1 + monthlyRate) + monthlyContribution
            }
            points.append(BalancePoint(year: year, value: balance))
        }
        return points
    }

    public static func clamped(
        principal: Double,
        annualPercent: Double,
        years: Int,
        monthly: Double
    ) -> (principal: Double, annualRate: Double, years: Int, monthly: Double) {
        let cash = min(max(principal, 0), 100_000)
        let rate = min(max(annualPercent, 0), 20) / 100
        let span = min(max(years, 1), 40)
        let extra = min(max(monthly, 0), 5_000)
        return (cash, rate, span, extra)
    }
}

public enum OpenLicense {
    public static func isAllowed(_ license: String) -> Bool {
        let folded = license.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
        if folded.contains("nc") || folded.contains("nd") {
            return false
        }
        if folded.contains("public domain") || folded == "cc0" || folded.hasPrefix("cc0 ") {
            return true
        }
        if folded.hasPrefix("cc by-sa") || folded.hasPrefix("cc by ") || folded == "cc by" {
            return true
        }
        return false
    }
}

public enum FigureLibrary {
    public static func loadBundled() throws -> StudyLibrary {
        guard let dataURL = Bundle.module.url(forResource: "Data", withExtension: nil),
              let creditsURL = Bundle.module.url(forResource: "credits", withExtension: "json", subdirectory: "Media")
                ?? Bundle.module.url(forResource: "credits", withExtension: "json")
        else {
            throw ContentError.invalid("No están los datos o los créditos de las fotos.")
        }
        return try load(dataDirectory: dataURL, creditsURL: creditsURL)
    }

    public static func load(dataDirectory: URL, creditsURL: URL) throws -> StudyLibrary {
        let files = try FileManager.default.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let decoder = JSONDecoder()
        var datasets: [StudyDataset] = []
        for file in files {
            let data = try Data(contentsOf: file)
            datasets.append(try decoder.decode(StudyDataset.self, from: data))
        }
        let photos = try decoder.decode([PhotoCredit].self, from: Data(contentsOf: creditsURL))
        return StudyLibrary(datasets: datasets, photos: photos, mediaDirectory: creditsURL.deletingLastPathComponent())
    }

    public static func validate(catalog: Catalog, library: StudyLibrary) throws {
        var datasetIDs: Set<String> = []
        for dataset in library.datasets {
            guard datasetIDs.insert(dataset.id).inserted else {
                throw ContentError.invalid("Dato repetido: \(dataset.id)")
            }
            if dataset.source.institution.isEmpty || dataset.source.dataset.isEmpty || dataset.source.date.isEmpty {
                throw ContentError.invalid("El dato \(dataset.id) no cita fuente.")
            }
            if dataset.kind == "line" || dataset.kind == "bar" {
                if dataset.points.count < 2 {
                    throw ContentError.invalid("La serie \(dataset.id) no tiene puntos.")
                }
            }
            if dataset.kind == "sketch" {
                if !dataset.diagram {
                    throw ContentError.invalid("El esquema \(dataset.id) tiene que marcarse como diagrama.")
                }
                if dataset.places.count != 24 {
                    throw ContentError.invalid("El esquema de provincias tiene que listar 24.")
                }
            }
            if dataset.exampleData && !DataCaution.caption(dataset).contains(DataCaution.exampleBanner) {
                throw ContentError.invalid("Los datos de ejemplo de \(dataset.id) no avisan en el texto.")
            }
        }
        var photoIDs: Set<String> = []
        for photo in library.photos {
            guard photoIDs.insert(photo.id).inserted else {
                throw ContentError.invalid("Foto repetida: \(photo.id)")
            }
            if photo.author.trimmingCharacters(in: .whitespaces).isEmpty {
                throw ContentError.invalid("La foto \(photo.id) no tiene autor.")
            }
            if !OpenLicense.isAllowed(photo.license) {
                throw ContentError.invalid("La licencia de \(photo.id) no es dominio público ni CC BY o CC BY-SA.")
            }
            if let directory = library.mediaDirectory {
                let file = directory.appendingPathComponent(photo.file)
                if !FileManager.default.fileExists(atPath: file.path) {
                    throw ContentError.invalid("Falta el archivo de la foto \(photo.id).")
                }
            }
        }
        for course in catalog.courses {
            for lesson in course.lessonsInOrder {
                for figure in lesson.resolvedFigures {
                    switch figure.kind {
                    case "chart", "sketch":
                        guard library.dataset(id: figure.ref) != nil else {
                            throw ContentError.invalid("La lección \(lesson.id) cita un dato que no existe: \(figure.ref)")
                        }
                    case "photo":
                        guard library.photo(id: figure.ref) != nil else {
                            throw ContentError.invalid("La lección \(lesson.id) cita una foto que no existe: \(figure.ref)")
                        }
                    case "calculator":
                        if figure.ref != CompoundInterest.calculatorID {
                            throw ContentError.invalid("Calculadora desconocida en \(lesson.id).")
                        }
                    default:
                        throw ContentError.invalid("Figura desconocida en \(lesson.id): \(figure.kind)")
                    }
                }
            }
        }
    }
}
