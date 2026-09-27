import Foundation

public enum AsambleaSchema {
    public static let name = "lufy.asamblea.v1"
    public static let payloadFile = "asamblea.json"
    public static let provinceTool = "tu-provincia"
}

public struct FeedFileEntry: Codable, Equatable, Sendable {
    public var name: String
    public var sha256: String

    public init(name: String, sha256: String) {
        self.name = name
        self.sha256 = sha256
    }

    private enum CodingKeys: String, CodingKey {
        case name, sha256
    }
}

public struct FeedManifest: Codable, Equatable, Sendable {
    public var schema: String
    public var updatedAt: String
    public var exampleData: Bool
    public var files: [FeedFileEntry]

    public init(schema: String, updatedAt: String, exampleData: Bool, files: [FeedFileEntry]) {
        self.schema = schema
        self.updatedAt = updatedAt
        self.exampleData = exampleData
        self.files = files
    }

    private enum CodingKeys: String, CodingKey {
        case schema
        case updatedAt = "updated_at"
        case exampleData = "example_data"
        case files
    }

    public func file(named name: String) -> FeedFileEntry? {
        files.first { $0.name == name }
    }
}

public struct FeedSource: Codable, Equatable, Sendable {
    public var institution: String
    public var dataset: String
    public var date: String
    public var note: String

    public init(institution: String, dataset: String, date: String, note: String) {
        self.institution = institution
        self.dataset = dataset
        self.date = date
        self.note = note
    }
}

public struct RecordedVote: Codable, Equatable, Sendable, Identifiable {
    public var date: String
    public var title: String
    public var choice: String
    public var source: String

    public var id: String { "\(date)|\(title)" }

    public init(date: String, title: String, choice: String, source: String) {
        self.date = date
        self.title = title
        self.choice = choice
        self.source = source
    }

    public var choiceLabel: String {
        switch choice {
        case "afavor": return "A favor"
        case "encontra": return "En contra"
        case "abstencion": return "Abstención"
        case "ausente": return "Ausente"
        case "blanco": return "Blanco"
        default: return choice
        }
    }
}

public struct LicensedPhoto: Codable, Equatable, Sendable {
    public var url: String
    public var author: String
    public var license: String
    public var licenseURL: String
    public var sourceURL: String

    public init(url: String, author: String, license: String, licenseURL: String, sourceURL: String) {
        self.url = url
        self.author = author
        self.license = license
        self.licenseURL = licenseURL
        self.sourceURL = sourceURL
    }

    private enum CodingKeys: String, CodingKey {
        case url, author, license
        case licenseURL = "license_url"
        case sourceURL = "source_url"
    }
}

public struct Legislator: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var publicName: String
    public var districtKind: String
    public var district: String
    public var party: String
    public var committees: [String]
    public var votes: [RecordedVote]
    public var photo: LicensedPhoto?

    public init(
        id: String,
        publicName: String,
        districtKind: String,
        district: String,
        party: String,
        committees: [String],
        votes: [RecordedVote],
        photo: LicensedPhoto? = nil
    ) {
        self.id = id
        self.publicName = publicName
        self.districtKind = districtKind
        self.district = district
        self.party = party
        self.committees = committees
        self.votes = votes
        self.photo = photo
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case publicName = "public_name"
        case districtKind = "district_kind"
        case district, party, committees, votes, photo
    }

    public var partyLabel: String {
        let trimmed = party.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sin organización registrada" : trimmed
    }
}

public struct AsambleaDirectory: Codable, Equatable, Sendable {
    public var schema: String
    public var exampleData: Bool
    public var updatedAt: String
    public var source: FeedSource
    public var legislators: [Legislator]

    public init(
        schema: String,
        exampleData: Bool,
        updatedAt: String,
        source: FeedSource,
        legislators: [Legislator]
    ) {
        self.schema = schema
        self.exampleData = exampleData
        self.updatedAt = updatedAt
        self.source = source
        self.legislators = legislators
    }

    private enum CodingKeys: String, CodingKey {
        case schema
        case exampleData = "example_data"
        case updatedAt = "updated_at"
        case source, legislators
    }

    public func legislators(in district: String) -> [Legislator] {
        let key = FeedText.fold(district)
        return legislators.filter { person in
            if key == FeedText.fold("Nacional") {
                return person.districtKind == "national"
            }
            if key == FeedText.fold("Exterior") {
                return person.districtKind == "exterior"
            }
            return person.districtKind == "province" && FeedText.fold(person.district) == key
        }
    }
}

public enum FeedRefreshPlan: Equatable, Sendable {
    case download
    case useCached

    public static func decide(lastSuccessDay: String?, today: String) -> FeedRefreshPlan {
        if let lastSuccessDay, lastSuccessDay == today {
            return .useCached
        }
        return .download
    }
}

public enum FeedStamp {
    public static func label(updatedAt: String) -> String {
        let day = String(updatedAt.prefix(10))
        guard let civil = CivilDay(iso: day) else {
            return "Actualizado: \(updatedAt)"
        }
        let months = [
            "", "enero", "febrero", "marzo", "abril", "mayo", "junio",
            "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
        ]
        let month = months.indices.contains(civil.month) ? months[civil.month] : ""
        return "Actualizado: \(civil.day) de \(month) de \(civil.year)"
    }
}

public enum FeedText {
    public static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum PublicRoleError: Error, Equatable, CustomStringConvertible {
    case invalid(String)

    public var description: String {
        switch self {
        case .invalid(let message): return message
        }
    }
}

public enum PublicRoleGate {
    public static let forbiddenKeyFragments = [
        "cedula", "email", "correo", "direccion", "domicilio", "telefono",
        "familia", "conyuge", "hijo", "patrimonio", "bienes", "activos",
    ]
    public static let forbiddenPhrases = ["corrupto", "culpable", "testaferro", "delincuente"]
    public static let voteChoices: Set<String> = ["afavor", "encontra", "abstencion", "ausente", "blanco"]
    public static let districtKinds: Set<String> = ["province", "national", "exterior"]

    public static func validate(data: Data) throws -> AsambleaDirectory {
        let object = try JSONSerialization.jsonObject(with: data)
        try walk(object, key: "")
        let directory = try JSONDecoder().decode(AsambleaDirectory.self, from: data)
        if directory.schema != AsambleaSchema.name {
            throw PublicRoleError.invalid("El esquema \(directory.schema) no es \(AsambleaSchema.name).")
        }
        var seen: Set<String> = []
        for person in directory.legislators {
            if !seen.insert(person.id).inserted {
                throw PublicRoleError.invalid("Identificador repetido: \(person.id)")
            }
            if person.publicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw PublicRoleError.invalid("Falta el nombre público de \(person.id).")
            }
            if !districtKinds.contains(person.districtKind) {
                throw PublicRoleError.invalid("Circunscripción desconocida en \(person.id).")
            }
            for vote in person.votes {
                if !voteChoices.contains(vote.choice) {
                    throw PublicRoleError.invalid("Voto desconocido en \(person.id).")
                }
                if vote.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw PublicRoleError.invalid("El voto de \(person.id) no tiene fuente.")
                }
            }
            if let photo = person.photo {
                if !OpenLicense.isAllowed(photo.license) || photo.author.isEmpty || photo.sourceURL.isEmpty {
                    throw PublicRoleError.invalid("La foto de \(person.id) no tiene licencia abierta, autor y origen.")
                }
            }
        }
        return directory
    }

    public static func validate(manifest data: Data) throws -> FeedManifest {
        let manifest = try JSONDecoder().decode(FeedManifest.self, from: data)
        if manifest.schema != AsambleaSchema.name {
            throw PublicRoleError.invalid("El manifiesto no es \(AsambleaSchema.name).")
        }
        if manifest.file(named: AsambleaSchema.payloadFile) == nil {
            throw PublicRoleError.invalid("El manifiesto no incluye \(AsambleaSchema.payloadFile).")
        }
        return manifest
    }

    private static func walk(_ value: Any, key: String) throws {
        let foldedKey = FeedText.fold(key).replacingOccurrences(of: "_", with: "")
        if forbiddenKeyFragments.contains(where: { foldedKey.contains($0) }) {
            throw PublicRoleError.invalid("El campo \(key) no es un dato de función pública.")
        }
        if let text = value as? String {
            try screen(text)
        } else if let list = value as? [Any] {
            for item in list {
                try walk(item, key: key)
            }
        } else if let object = value as? [String: Any] {
            for (child, nested) in object {
                try walk(nested, key: child)
            }
        }
    }

    private static func screen(_ text: String) throws {
        let folded = FeedText.fold(text)
        for phrase in forbiddenPhrases where folded.contains(phrase) {
            throw PublicRoleError.invalid("El texto usa una etiqueta que esta app no publica.")
        }
        if text.range(of: #"\b\d{10}\b"#, options: .regularExpression) != nil {
            throw PublicRoleError.invalid("El texto incluye un número de diez dígitos.")
        }
        if text.range(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.regularExpression, .caseInsensitive]) != nil {
            throw PublicRoleError.invalid("El texto incluye un correo.")
        }
    }
}

public enum FeedLibrary {
    public static func loadBundled() throws -> AsambleaDirectory {
        guard let url = Bundle.module.url(forResource: AsambleaSchema.payloadFile, withExtension: nil, subdirectory: "Feed")
            ?? Bundle.module.url(forResource: "asamblea", withExtension: "json")
        else {
            throw PublicRoleError.invalid("No está la copia local de la Asamblea.")
        }
        return try PublicRoleGate.validate(data: Data(contentsOf: url))
    }
}
