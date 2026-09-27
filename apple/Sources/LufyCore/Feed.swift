import Foundation

public enum RitmoFeed {
    public static let intervalo: TimeInterval = 24 * 60 * 60

    /// La consulta del manifiesto ocurre al abrir, y como mucho una vez al día.
    /// Si el reloj retrocede, se vuelve a consultar.
    public static func debeConsultar(ultima: Date?, ahora: Date, intervalo: TimeInterval = intervalo) -> Bool {
        guard let ultima else { return true }
        let delta = ahora.timeIntervalSince(ultima)
        if delta < 0 { return true }
        return delta >= intervalo
    }

    public static func interpretarMarca(_ texto: String) -> Date? {
        guard texto.count == 20, texto.hasSuffix("Z"), texto.dropFirst(10).hasPrefix("T") else { return nil }
        let fecha = String(texto.prefix(10))
        guard Fechas.isoValida(fecha) else { return nil }
        let hora = texto.dropFirst(11).dropLast()
        let partes = hora.split(separator: ":", omittingEmptySubsequences: false)
        guard partes.count == 3,
              partes[0].count == 2, partes[1].count == 2, partes[2].count == 2,
              let horas = Int(partes[0]), let minutos = Int(partes[1]), let segundos = Int(partes[2]),
              (0..<24).contains(horas), (0..<60).contains(minutos), (0..<60).contains(segundos) else {
            return nil
        }
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let trozos = fecha.split(separator: "-")
        var componentes = DateComponents()
        componentes.calendar = calendario
        componentes.timeZone = calendario.timeZone
        componentes.year = Int(trozos[0])
        componentes.month = Int(trozos[1])
        componentes.day = Int(trozos[2])
        componentes.hour = horas
        componentes.minute = minutos
        componentes.second = segundos
        return calendario.date(from: componentes)
    }

    public static func marcaValida(_ texto: String) -> Bool {
        Fechas.isoValida(texto) || interpretarMarca(texto) != nil
    }

    public static func fechaVisible(_ texto: String) -> String? {
        let prefijo = String(texto.prefix(10))
        guard Fechas.isoValida(prefijo) else { return nil }
        return prefijo
    }
}

public struct ArchivoFeed: Decodable, Sendable, Equatable, Identifiable {
    public let path: String
    public let sha256: String
    public let updatedAt: String
    public let bytes: Int

    public var id: String { path }

    private enum CodingKeys: String, CodingKey {
        case path
        case sha256
        case updatedAt = "updated_at"
        case bytes
    }
}

/// Manifiesto genérico: lo puede publicar esta app o cualquier otra que
/// comparta el mismo índice versionado.
public struct ManifiestoFeed: Decodable, Sendable, Equatable {
    public static let schemaActual = 1
    public static let topeBytes = 4_194_304

    public let schema: Int
    public let id: String
    public let updatedAt: String
    public let files: [ArchivoFeed]

    private enum CodingKeys: String, CodingKey {
        case schema
        case id
        case updatedAt = "updated_at"
        case files
    }

    public func validar() throws {
        guard schema == Self.schemaActual else { throw ErrorLufy.schema(schema) }
        guard id.range(of: "^[a-z0-9-]{1,32}$", options: .regularExpression) != nil else {
            throw ErrorLufy.contenidoIncompleto("id del feed")
        }
        guard RitmoFeed.marcaValida(updatedAt) else { throw ErrorLufy.fechaInvalida(updatedAt) }
        guard !files.isEmpty else { throw ErrorLufy.contenidoIncompleto("archivos") }
        var vistos = Set<String>()
        for archivo in files {
            guard Self.rutaSegura(archivo.path) else { throw ErrorLufy.enlaceProhibido(archivo.path) }
            guard vistos.insert(archivo.path).inserted else {
                throw ErrorLufy.contenidoIncompleto("ruta repetida")
            }
            guard archivo.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
                throw ErrorLufy.archivoInvalido("huella")
            }
            guard RitmoFeed.marcaValida(archivo.updatedAt) else { throw ErrorLufy.fechaInvalida(archivo.updatedAt) }
            guard archivo.bytes > 0, archivo.bytes <= Self.topeBytes else {
                throw ErrorLufy.contenidoIncompleto("tamano")
            }
        }
    }

    public func pendientes(hashesLocales: [String: String]) -> [ArchivoFeed] {
        files.filter { hashesLocales[$0.path] != $0.sha256 }
    }

    public static func coincide(_ datos: Data, con archivo: ArchivoFeed) -> Bool {
        datos.count == archivo.bytes && Huella.sha256(datos) == archivo.sha256
    }

    public static func rutaSegura(_ ruta: String) -> Bool {
        guard !ruta.isEmpty, ruta.count <= 180 else { return false }
        guard !ruta.hasPrefix("/"), !ruta.contains(".."), !ruta.contains("\\") else { return false }
        guard !ruta.contains("?"), !ruta.contains("#"), !ruta.contains(":") else { return false }
        guard ruta.unicodeScalars.allSatisfy({ !CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            return false
        }
        let partes = ruta.split(separator: "/", omittingEmptySubsequences: false)
        guard !partes.isEmpty, !partes.contains("") else { return false }
        return partes.allSatisfy { parte in
            parte.unicodeScalars.allSatisfy { scalar in
                CharacterSet.alfanumericoFeed.contains(scalar) || scalar == "-" || scalar == "_" || scalar == "."
            }
        }
    }
}

private extension CharacterSet {
    static let alfanumericoFeed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
}

public enum RevisionJSON {
    public static func auditar(_ datos: Data) throws {
        let objeto: Any
        do {
            objeto = try JSONSerialization.jsonObject(with: datos)
        } catch {
            throw ErrorLufy.json(String(describing: error))
        }
        try caminar(objeto)
    }

    private static func caminar(_ valor: Any) throws {
        switch valor {
        case let texto as String:
            try PoliticaEnlaces.auditarPalabras(texto)
        case let lista as [Any]:
            for elemento in lista {
                try caminar(elemento)
            }
        case let mapa as [String: Any]:
            for (clave, contenido) in mapa {
                if claveSensible(clave) {
                    throw ErrorLufy.textoProhibido("campo")
                }
                try caminar(contenido)
            }
        case let numero as NSNumber:
            let texto = numero.stringValue
            if texto.range(of: "^\\d{10}$", options: .regularExpression) != nil {
                throw ErrorLufy.textoProhibido("cedula")
            }
        default:
            break
        }
    }

    private static func claveSensible(_ clave: String) -> Bool {
        let plana = clave.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        let prohibidas: Set<String> = [
            "cedula", "email", "correo", "mail", "domicilio", "direccion",
            "telefono", "patrimonio", "declaracion", "familia", "conyuge", "hijos", "monto",
        ]
        return prohibidas.contains(plana)
    }
}
