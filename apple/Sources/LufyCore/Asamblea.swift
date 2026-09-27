import Foundation

public enum LicenciaFoto: String, Decodable, Sendable, Equatable {
    case dominioPublico = "dominio-publico"
    case cc0 = "cc0"
    case ccBy = "cc-by"
}

public struct FotoPublica: Decodable, Sendable, Equatable {
    public let ruta: String
    public let licencia: LicenciaFoto
    public let atribucion: String

    public var puedeMostrarse: Bool { true }

    public func validar(origen: String) throws {
        guard !atribucion.isEmpty else { throw ErrorLufy.contenidoIncompleto("atribucion") }
        guard PoliticaEnlaces.urlLufy(origen: origen, ruta: ruta) != nil else {
            throw ErrorLufy.enlaceProhibido(ruta)
        }
    }
}

public struct PeriodoPublico: Decodable, Sendable, Equatable {
    public let id: String
    public let etiqueta: String
    public let inicio: String
    public let fin: String?
}

public struct ProyectoLey: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let fecha: String
    public let estado: String
    public let fuente: Fuente
}

public struct AsistenciaPublica: Decodable, Sendable, Equatable {
    public let sesiones: Int
    public let presente: Int
    public let fuente: Fuente

    public func validar(origen: String) throws {
        guard sesiones >= 0, presente >= 0, presente <= sesiones else {
            throw ErrorLufy.contenidoIncompleto("asistencia")
        }
        try fuente.validar(origen: origen)
    }
}

public struct Asambleista: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let nombre: String
    public let foto: FotoPublica?
    public let provincia: String
    public let circunscripcion: String
    public let partido: String
    public let bloque: String
    public let comisiones: [String]
    public let periodo: String
    public let proyectos: [ProyectoLey]
    public let asistencia: AsistenciaPublica?
    public let hallazgos: [String]
}

public struct IndiceAsamblea: Decodable, Sendable, Equatable {
    public static let schemaActual = 1

    public let schema: Int
    public let ejemplo: Bool
    public let aviso: String
    public let updatedAt: String
    public let periodo: PeriodoPublico
    public let asambleistas: [Asambleista]

    private enum CodingKeys: String, CodingKey {
        case schema
        case ejemplo
        case aviso
        case updatedAt = "updated_at"
        case periodo
        case asambleistas
    }

    public func persona(id: String) -> Asambleista? {
        asambleistas.first { $0.id == id }
    }
}

public enum SentidoVoto: String, Decodable, Sendable, Equatable, CaseIterable {
    case afavor
    case enContra = "en_contra"
    case abstencion
    case ausente
    case blanco

    /// Texto fijo del sentido registrado. No es un sello.
    public var etiqueta: String {
        switch self {
        case .afavor: "A favor"
        case .enContra: "En contra"
        case .abstencion: "Abstención"
        case .ausente: "Ausente"
        case .blanco: "En blanco"
        }
    }
}

public struct VotoRegistro: Decodable, Sendable, Equatable, Identifiable {
    public let asambleistaId: String
    public let voto: SentidoVoto

    public var id: String { asambleistaId }

    private enum CodingKeys: String, CodingKey {
        case asambleistaId = "asambleista_id"
        case voto
    }
}

public struct Votacion: Decodable, Sendable, Equatable, Identifiable {
    public static let schemaActual = 1

    public let schema: Int
    public let id: String
    public let fecha: String
    public let titulo: String
    public let sesion: String
    public let acta: String
    public let fuente: Fuente
    public let votos: [VotoRegistro]
}

public struct HallazgoPublico: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let sello: Sello
    public let titulo: String
    public let texto: String
    public let tema: String
    public let asambleistas: [String]
    public let fuente: Fuente
    public let earlyAccessUntil: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case sello
        case titulo
        case texto
        case tema
        case asambleistas
        case fuente
        case earlyAccessUntil = "early_access_until"
    }
}

public struct DossierPublico: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let texto: String
    public let tema: String
    public let producto: String
    public let earlyAccessUntil: String?
    public let archivo: CopiaArchivada?
    public let fuente: Fuente

    private enum CodingKeys: String, CodingKey {
        case id
        case titulo
        case texto
        case tema
        case producto
        case archivo
        case fuente
        case earlyAccessUntil = "early_access_until"
    }
}

public struct IndiceDossiers: Decodable, Sendable, Equatable {
    public static let schemaActual = 1

    public let schema: Int
    public let ejemplo: Bool
    public let updatedAt: String
    public let dossiers: [DossierPublico]

    private enum CodingKeys: String, CodingKey {
        case schema
        case ejemplo
        case updatedAt = "updated_at"
        case dossiers
    }
}

public struct PaqueteFeed: Sendable, Equatable {
    public let asamblea: IndiceAsamblea
    public let hallazgos: IndiceHallazgos
    public let votaciones: [Votacion]
    public let dossiers: IndiceDossiers?
}

public struct IndiceHallazgos: Decodable, Sendable, Equatable {
    public static let schemaActual = 1

    public let schema: Int
    public let ejemplo: Bool
    public let updatedAt: String
    public let hallazgos: [HallazgoPublico]

    private enum CodingKeys: String, CodingKey {
        case schema
        case ejemplo
        case updatedAt = "updated_at"
        case hallazgos
    }
}

public enum NombresPublicos {
    public static func iniciales(_ nombre: String) -> String {
        let partes = nombre.split(whereSeparator: \.isWhitespace).map(String.init).filter { parte in
            parte.contains(where: \.isLetter)
        }
        let letras = partes.prefix(2).compactMap { $0.first(where: \.isLetter) }
        guard !letras.isEmpty else { return "·" }
        return String(letras).uppercased(with: Locale(identifier: "es"))
    }
}

public enum ConjuntoAsamblea {
    public static func validar(
        asamblea datosAsamblea: Data,
        hallazgos datosHallazgos: Data,
        votaciones: [(ruta: String, datos: Data)],
        origen: String
    ) throws -> (IndiceAsamblea, IndiceHallazgos, [Votacion]) {
        let paquete = try paquete(
            asamblea: datosAsamblea,
            hallazgos: datosHallazgos,
            votaciones: votaciones,
            origen: origen,
            dossiers: nil
        )
        return (paquete.asamblea, paquete.hallazgos, paquete.votaciones)
    }

    public static func paquete(
        asamblea datosAsamblea: Data,
        hallazgos datosHallazgos: Data,
        votaciones: [(ruta: String, datos: Data)],
        origen: String,
        dossiers datosDossiers: Data? = nil
    ) throws -> PaqueteFeed {
        try RevisionJSON.auditar(datosAsamblea)
        try RevisionJSON.auditar(datosHallazgos)
        for item in votaciones {
            guard ManifiestoFeed.rutaSegura(item.ruta), item.ruta.hasPrefix("votaciones/"), item.ruta.hasSuffix(".json") else {
                throw ErrorLufy.enlaceProhibido(item.ruta)
            }
            try RevisionJSON.auditar(item.datos)
        }
        if let datosDossiers {
            try RevisionJSON.auditar(datosDossiers)
        }
        try exigirForma(datosAsamblea, tipo: .asamblea)
        try exigirForma(datosHallazgos, tipo: .hallazgos)
        for item in votaciones {
            try exigirForma(item.datos, tipo: .votacion)
        }
        if let datosDossiers {
            try exigirForma(datosDossiers, tipo: .dossiers)
        }

        let asamblea = try decodificar(IndiceAsamblea.self, datosAsamblea)
        let indiceHallazgos = try decodificar(IndiceHallazgos.self, datosHallazgos)
        let sesiones = try votaciones.map { try decodificar(Votacion.self, $0.datos) }
        let indiceDossiers = try datosDossiers.map { try decodificar(IndiceDossiers.self, $0) }
        try semantica(
            asamblea: asamblea,
            hallazgos: indiceHallazgos,
            votaciones: sesiones,
            dossiers: indiceDossiers,
            origen: origen
        )
        return PaqueteFeed(
            asamblea: asamblea,
            hallazgos: indiceHallazgos,
            votaciones: sesiones,
            dossiers: indiceDossiers
        )
    }

    private static func decodificar<T: Decodable>(_ tipo: T.Type, _ datos: Data) throws -> T {
        do {
            return try JSONDecoder().decode(tipo, from: datos)
        } catch let error as ErrorLufy {
            throw error
        } catch {
            throw ErrorLufy.json(String(describing: error))
        }
    }

    private static func semantica(
        asamblea: IndiceAsamblea,
        hallazgos: IndiceHallazgos,
        votaciones: [Votacion],
        dossiers: IndiceDossiers?,
        origen: String
    ) throws {
        guard asamblea.schema == IndiceAsamblea.schemaActual else { throw ErrorLufy.schema(asamblea.schema) }
        guard hallazgos.schema == IndiceHallazgos.schemaActual else { throw ErrorLufy.schema(hallazgos.schema) }
        guard asamblea.ejemplo == hallazgos.ejemplo else { throw ErrorLufy.contenidoIncompleto("ejemplo") }
        guard RitmoFeed.marcaValida(asamblea.updatedAt) else { throw ErrorLufy.fechaInvalida(asamblea.updatedAt) }
        guard RitmoFeed.marcaValida(hallazgos.updatedAt) else { throw ErrorLufy.fechaInvalida(hallazgos.updatedAt) }
        guard Fechas.isoValida(asamblea.periodo.inicio) else { throw ErrorLufy.fechaInvalida(asamblea.periodo.inicio) }
        if let fin = asamblea.periodo.fin {
            guard Fechas.isoValida(fin) else { throw ErrorLufy.fechaInvalida(fin) }
        }
        guard !asamblea.periodo.id.isEmpty, !asamblea.periodo.etiqueta.isEmpty else {
            throw ErrorLufy.contenidoIncompleto("periodo")
        }
        guard !asamblea.asambleistas.isEmpty else { throw ErrorLufy.contenidoIncompleto("asamblea") }

        if asamblea.ejemplo {
            let aviso = asamblea.aviso.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            guard aviso.contains("ejemplo") else { throw ErrorLufy.contenidoIncompleto("aviso") }
        }

        var ids = Set<String>()
        var proyectos = Set<String>()
        for persona in asamblea.asambleistas {
            guard ids.insert(persona.id).inserted else { throw ErrorLufy.contenidoIncompleto("id repetido") }
            guard identificador(persona.id) else { throw ErrorLufy.contenidoIncompleto("id") }
            guard !persona.nombre.isEmpty, !persona.provincia.isEmpty, !persona.circunscripcion.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("perfil")
            }
            guard !persona.partido.isEmpty, !persona.bloque.isEmpty, !persona.periodo.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("perfil")
            }
            if asamblea.ejemplo {
                let nombre = persona.nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
                guard nombre.contains("ejemplo") else { throw ErrorLufy.contenidoIncompleto("nombre de ejemplo") }
            }
            try persona.foto?.validar(origen: origen)
            for comision in persona.comisiones where comision.isEmpty {
                throw ErrorLufy.contenidoIncompleto("comision")
            }
            for proyecto in persona.proyectos {
                guard proyectos.insert(proyecto.id).inserted, identificador(proyecto.id) else {
                    throw ErrorLufy.contenidoIncompleto("proyecto")
                }
                guard Fechas.isoValida(proyecto.fecha), !proyecto.titulo.isEmpty, !proyecto.estado.isEmpty else {
                    throw ErrorLufy.contenidoIncompleto("proyecto")
                }
                try proyecto.fuente.validar(origen: origen)
            }
            try persona.asistencia?.validar(origen: origen)
            guard Set(persona.hallazgos).count == persona.hallazgos.count else {
                throw ErrorLufy.contenidoIncompleto("hallazgos")
            }
        }

        var idsHallazgo = Set<String>()
        var citados: [String: Set<String>] = [:]
        for hallazgo in hallazgos.hallazgos {
            guard idsHallazgo.insert(hallazgo.id).inserted, identificador(hallazgo.id) else {
                throw ErrorLufy.contenidoIncompleto("hallazgo")
            }
            guard !hallazgo.titulo.isEmpty, !hallazgo.texto.isEmpty, !hallazgo.asambleistas.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("hallazgo")
            }
            guard hallazgo.tema.count <= 80 else { throw ErrorLufy.contenidoIncompleto("tema") }
            if let hasta = hallazgo.earlyAccessUntil {
                guard AccesoTemprano.instante(hasta) != nil else { throw ErrorLufy.fechaInvalida(hasta) }
            }
            guard Set(hallazgo.asambleistas).count == hallazgo.asambleistas.count else {
                throw ErrorLufy.contenidoIncompleto("hallazgo")
            }
            for id in hallazgo.asambleistas {
                guard ids.contains(id) else { throw ErrorLufy.contenidoIncompleto("hallazgo sin perfil") }
                citados[id, default: []].insert(hallazgo.id)
            }
            try hallazgo.fuente.validar(origen: origen)
        }
        for persona in asamblea.asambleistas {
            guard Set(persona.hallazgos) == citados[persona.id, default: []] else {
                throw ErrorLufy.contenidoIncompleto("hallazgos del perfil")
            }
        }

        var idsVoto = Set<String>()
        for sesion in votaciones {
            guard sesion.schema == Votacion.schemaActual else { throw ErrorLufy.schema(sesion.schema) }
            guard idsVoto.insert(sesion.id).inserted, identificador(sesion.id) else {
                throw ErrorLufy.contenidoIncompleto("votacion")
            }
            guard Fechas.isoValida(sesion.fecha) else { throw ErrorLufy.fechaInvalida(sesion.fecha) }
            guard !sesion.titulo.isEmpty, !sesion.sesion.isEmpty, !sesion.acta.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("votacion")
            }
            try sesion.fuente.validar(origen: origen)
            var vistos = Set<String>()
            for registro in sesion.votos {
                guard ids.contains(registro.asambleistaId) else {
                    throw ErrorLufy.contenidoIncompleto("voto sin perfil")
                }
                guard vistos.insert(registro.asambleistaId).inserted else {
                    throw ErrorLufy.contenidoIncompleto("voto repetido")
                }
            }
        }

        if let dossiers {
            guard dossiers.schema == IndiceDossiers.schemaActual else { throw ErrorLufy.schema(dossiers.schema) }
            guard dossiers.ejemplo == asamblea.ejemplo else { throw ErrorLufy.contenidoIncompleto("ejemplo") }
            guard RitmoFeed.marcaValida(dossiers.updatedAt) else { throw ErrorLufy.fechaInvalida(dossiers.updatedAt) }
            var idsDossier = Set<String>()
            for dossier in dossiers.dossiers {
                guard idsDossier.insert(dossier.id).inserted, identificador(dossier.id) else {
                    throw ErrorLufy.contenidoIncompleto("dossier")
                }
                guard !dossier.titulo.isEmpty, !dossier.texto.isEmpty else {
                    throw ErrorLufy.contenidoIncompleto("dossier")
                }
                guard dossier.tema.count <= 80 else { throw ErrorLufy.contenidoIncompleto("tema") }
                guard dossier.producto.range(of: "^[a-z0-9.]{3,80}$", options: .regularExpression) != nil else {
                    throw ErrorLufy.contenidoIncompleto("producto")
                }
                if dossiers.ejemplo {
                    let titulo = dossier.titulo.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
                    guard titulo.contains("ejemplo") else { throw ErrorLufy.contenidoIncompleto("dossier de ejemplo") }
                }
                if let hasta = dossier.earlyAccessUntil {
                    guard AccesoTemprano.instante(hasta) != nil else { throw ErrorLufy.fechaInvalida(hasta) }
                }
                try dossier.archivo?.validar(origen: origen)
                try dossier.fuente.validar(origen: origen)
            }
        }
    }

    private static func identificador(_ texto: String) -> Bool {
        texto.range(of: "^[a-z0-9-]{1,64}$", options: .regularExpression) != nil
    }

    private enum TipoForma {
        case asamblea
        case hallazgos
        case votacion
        case dossiers
    }

    private static func exigirForma(_ datos: Data, tipo: TipoForma) throws {
        let objeto: Any
        do {
            objeto = try JSONSerialization.jsonObject(with: datos)
        } catch {
            throw ErrorLufy.json(String(describing: error))
        }
        guard let mapa = objeto as? [String: Any] else { throw ErrorLufy.contenidoIncompleto("objeto") }
        switch tipo {
        case .asamblea:
            try claves(mapa, ["schema", "ejemplo", "aviso", "updated_at", "periodo", "asambleistas"], "asamblea")
            try claves(mapa["periodo"] as? [String: Any], ["id", "etiqueta", "inicio", "fin"], "periodo")
            guard let personas = mapa["asambleistas"] as? [[String: Any]] else {
                throw ErrorLufy.contenidoIncompleto("asambleistas")
            }
            for persona in personas {
                try claves(persona, [
                    "id", "nombre", "foto", "provincia", "circunscripcion", "partido", "bloque",
                    "comisiones", "periodo", "proyectos", "asistencia", "hallazgos",
                ], "perfil")
                if let foto = persona["foto"] as? [String: Any] {
                    try claves(foto, ["ruta", "licencia", "atribucion"], "foto")
                }
                guard let proyectos = persona["proyectos"] as? [[String: Any]] else {
                    throw ErrorLufy.contenidoIncompleto("proyectos")
                }
                for proyecto in proyectos {
                    try claves(proyecto, ["id", "titulo", "fecha", "estado", "fuente"], "proyecto")
                    try fuente(proyecto["fuente"])
                }
                if let asistencia = persona["asistencia"] as? [String: Any] {
                    try claves(asistencia, ["sesiones", "presente", "fuente"], "asistencia")
                    try fuente(asistencia["fuente"])
                }
            }
        case .hallazgos:
            try claves(mapa, ["schema", "ejemplo", "updated_at", "hallazgos"], "hallazgos")
            guard let lista = mapa["hallazgos"] as? [[String: Any]] else {
                throw ErrorLufy.contenidoIncompleto("hallazgos")
            }
            for hallazgo in lista {
                try claves(
                    hallazgo,
                    ["id", "sello", "titulo", "texto", "tema", "asambleistas", "fuente", "early_access_until"],
                    "hallazgo"
                )
                try acceso(hallazgo["early_access_until"])
                try fuente(hallazgo["fuente"])
            }
        case .dossiers:
            try claves(mapa, ["schema", "ejemplo", "updated_at", "dossiers"], "dossiers")
            guard let lista = mapa["dossiers"] as? [[String: Any]] else {
                throw ErrorLufy.contenidoIncompleto("dossiers")
            }
            for dossier in lista {
                try claves(
                    dossier,
                    ["id", "titulo", "texto", "tema", "producto", "early_access_until", "archivo", "fuente"],
                    "dossier"
                )
                try acceso(dossier["early_access_until"])
                try fuente(dossier["fuente"])
            }
        case .votacion:
            try claves(mapa, ["schema", "id", "fecha", "titulo", "sesion", "acta", "fuente", "votos"], "votacion")
            try fuente(mapa["fuente"])
            guard let votos = mapa["votos"] as? [[String: Any]] else {
                throw ErrorLufy.contenidoIncompleto("votos")
            }
            for voto in votos {
                try claves(voto, ["asambleista_id", "voto"], "voto")
            }
        }
    }

    private static func acceso(_ valor: Any?) throws {
        if valor is NSNull { return }
        guard let texto = valor as? String, AccesoTemprano.instante(texto) != nil else {
            throw ErrorLufy.fechaInvalida("acceso")
        }
    }

    private static func fuente(_ valor: Any?) throws {
        guard let mapa = valor as? [String: Any] else { throw ErrorLufy.contenidoIncompleto("fuente") }
        try claves(mapa, ["institucion", "documento", "fecha", "linea", "archivo"], "fuente")
        if let archivo = mapa["archivo"] as? [String: Any] {
            try claves(archivo, ["ruta", "sha256", "archivado"], "archivo")
        }
    }

    private static func claves(_ mapa: [String: Any]?, _ permitidas: Set<String>, _ donde: String) throws {
        guard let mapa else { throw ErrorLufy.contenidoIncompleto(donde) }
        for clave in mapa.keys where !permitidas.contains(clave) {
            throw ErrorLufy.contenidoIncompleto(donde)
        }
        for clave in permitidas where mapa[clave] == nil {
            throw ErrorLufy.contenidoIncompleto(donde)
        }
    }
}
