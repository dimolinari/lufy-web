import Foundation

public struct Seguimiento: Codable, Sendable, Equatable, Identifiable {
    public enum Clase: String, Codable, Sendable {
        case legislador
        case institucion
        case tema
    }

    public let clase: Clase
    public let clave: String

    public var id: String { "\(clase.rawValue)|\(clave)" }

    public init(clase: Clase, clave: String) {
        self.clase = clase
        self.clave = clave
    }
}

public struct PiezaFeed: Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let lineaFuente: String
    public let sello: Sello?
    public let legisladores: [String]
    public let institucion: String
    public let tema: String

    public init(
        id: String,
        titulo: String,
        lineaFuente: String,
        sello: Sello?,
        legisladores: [String],
        institucion: String,
        tema: String
    ) {
        self.id = id
        self.titulo = titulo
        self.lineaFuente = lineaFuente
        self.sello = sello
        self.legisladores = legisladores
        self.institucion = institucion
        self.tema = tema
    }
}

public struct AvisoSeguimiento: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let lineaFuente: String
    public let sello: Sello?

    public init(id: String, titulo: String, lineaFuente: String, sello: Sello?) {
        self.id = id
        self.titulo = titulo
        self.lineaFuente = lineaFuente
        self.sello = sello
    }
}

public enum AvisosSeguimiento {
    /// La primera foto (`anteriores == nil`) no avisa.
    /// El título y la línea de fuente se copian de la pieza publicada.
    public static func novedades(
        anteriores: Set<String>?,
        piezas: [PiezaFeed],
        seguimientos: [Seguimiento]
    ) -> [AvisoSeguimiento] {
        guard let anteriores else { return [] }
        let vigentes = seguimientos.filter { !$0.clave.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !vigentes.isEmpty else { return [] }
        var avisos: [AvisoSeguimiento] = []
        var vistos = Set<String>()
        for pieza in piezas where !anteriores.contains(pieza.id) {
            guard vistos.insert(pieza.id).inserted, coincide(pieza, vigentes) else { continue }
            avisos.append(
                AvisoSeguimiento(
                    id: pieza.id,
                    titulo: pieza.titulo,
                    lineaFuente: pieza.lineaFuente,
                    sello: pieza.sello
                )
            )
        }
        return avisos
    }

    private static func coincide(_ pieza: PiezaFeed, _ seguimientos: [Seguimiento]) -> Bool {
        for seguimiento in seguimientos {
            switch seguimiento.clase {
            case .legislador:
                if pieza.legisladores.contains(seguimiento.clave) { return true }
            case .institucion:
                if igual(pieza.institucion, seguimiento.clave) { return true }
            case .tema:
                if !pieza.tema.isEmpty, igual(pieza.tema, seguimiento.clave) { return true }
            }
        }
        return false
    }

    private static func igual(_ izquierda: String, _ derecha: String) -> Bool {
        let opciones: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let locale = Locale(identifier: "es")
        return izquierda.folding(options: opciones, locale: locale)
            == derecha.folding(options: opciones, locale: locale)
    }
}
