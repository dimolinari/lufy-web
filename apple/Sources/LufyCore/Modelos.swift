import Foundation

public enum Sello: String, Codable, Sendable, Equatable, CaseIterable {
    case confirmado = "CONFIRMADO"
    case indicio = "INDICIO"
    case abierto = "ABIERTO"
    case hipotesis = "HIPÓTESIS"

    public var descripcionAccesible: String {
        switch self {
        case .confirmado:
            return "Sello confirmado. Lo documenta una fuente oficial."
        case .indicio:
            return "Sello indicio. Lo publicó una fuente seria y falta el documento oficial."
        case .abierto:
            return "Sello abierto. No hay datos oficiales suficientes. No se inventa la cifra."
        case .hipotesis:
            return "Sello hipótesis. Sirve para saber dónde mirar. No sirve para concluir."
        }
    }
}

public struct ArchivoLufy: Codable, Sendable, Equatable, Hashable {
    public var ruta: String
    public var sha256: String
    public var archivado: String
}

public struct Fuente: Codable, Sendable, Equatable, Hashable {
    public var institucion: String
    public var documento: String
    public var fecha: String
    public var archivo: ArchivoLufy?

    public var linea: String {
        "Fuente: \(institucion), \(documento), \(fecha)."
    }
}

public enum EstiloBarra: String, Codable, Sendable, Equatable {
    case vino
    case vinoRayado
    case oro
    case oroRayado
    case tinta
    case punto
}

public struct Barra: Codable, Sendable, Equatable {
    public var etiqueta: String
    public var texto: String
    public var numero: Double
    public var estilo: EstiloBarra
    public var ocr: Bool?
}

public struct LeyendaItem: Codable, Sendable, Equatable {
    public var estilo: EstiloBarra
    public var etiqueta: String
}

public struct Grafico: Codable, Sendable, Equatable {
    public var titulo: String
    public var nota: String
    public var leyenda: [LeyendaItem]?
    public var barras: [Barra]
}

public struct GrupoComparacion: Codable, Sendable, Equatable {
    public var nombre: String
    public var ocr: Bool?
    public var filas: [Barra]
}

public struct Comparaciones: Codable, Sendable, Equatable {
    public var titulo: String
    public var nota: String
    public var leyenda: [LeyendaItem]
    public var grupos: [GrupoComparacion]
}

public struct FilaTabla: Codable, Sendable, Equatable {
    public var celdas: [String]
    public var ocr: Bool?
}

public struct Tabla: Codable, Sendable, Equatable {
    public var titulo: String
    public var columnas: [String]
    public var filas: [FilaTabla]
    public var nota: String?
}

public struct ColumnaTexto: Codable, Sendable, Equatable {
    public var titulo: String
    public var items: [String]
}

public struct ParFicha: Codable, Sendable, Equatable {
    public var termino: String
    public var valor: String
}

public struct EntradaGlosario: Codable, Sendable, Equatable {
    public var termino: String
    public var definicion: String
}

public struct Evento: Codable, Sendable, Equatable {
    public var fecha: String
    public var iso: String
    public var texto: String
}

public struct DocumentoFuente: Codable, Sendable, Equatable {
    public var institucion: String
    public var documento: String
    public var fecha: String
    public var archivo: ArchivoLufy?
}

public struct ItemLeyenda: Codable, Sendable, Equatable {
    public var sello: Sello?
    public var marca: String?
    public var texto: String
}

public enum CualKoFi: String, Codable, Sendable, Equatable, Hashable {
    case apoyo
    case libro
    case muestra
}

public enum DestinoApp: Sendable, Equatable, Hashable {
    case inicio
    case apoyo
    case libro
    case datos
    case historia
    case privacidad
    case correcciones
    case hilo(String)
    case koFi(CualKoFi)
}

extension DestinoApp: Codable {
    private enum Clave: String, CodingKey {
        case tipo
        case id
    }

    public init(from decoder: Decoder) throws {
        let contenedor = try decoder.container(keyedBy: Clave.self)
        let tipo = try contenedor.decode(String.self, forKey: .tipo)
        switch tipo {
        case "inicio": self = .inicio
        case "apoyo": self = .apoyo
        case "libro": self = .libro
        case "datos": self = .datos
        case "historia": self = .historia
        case "privacidad": self = .privacidad
        case "correcciones": self = .correcciones
        case "hilo":
            self = .hilo(try contenedor.decode(String.self, forKey: .id))
        case "koFi":
            let id = try contenedor.decode(String.self, forKey: .id)
            guard let cual = CualKoFi(rawValue: id) else {
                throw ErrorContenido.validacion("Enlace de Ko-fi desconocido.")
            }
            self = .koFi(cual)
        default:
            throw ErrorContenido.validacion("Destino desconocido: \(tipo).")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var contenedor = encoder.container(keyedBy: Clave.self)
        switch self {
        case .inicio:
            try contenedor.encode("inicio", forKey: .tipo)
        case .apoyo:
            try contenedor.encode("apoyo", forKey: .tipo)
        case .libro:
            try contenedor.encode("libro", forKey: .tipo)
        case .datos:
            try contenedor.encode("datos", forKey: .tipo)
        case .historia:
            try contenedor.encode("historia", forKey: .tipo)
        case .privacidad:
            try contenedor.encode("privacidad", forKey: .tipo)
        case .correcciones:
            try contenedor.encode("correcciones", forKey: .tipo)
        case .hilo(let id):
            try contenedor.encode("hilo", forKey: .tipo)
            try contenedor.encode(id, forKey: .id)
        case .koFi(let cual):
            try contenedor.encode("koFi", forKey: .tipo)
            try contenedor.encode(cual.rawValue, forKey: .id)
        }
    }
}

public enum EstiloBoton: String, Codable, Sendable, Equatable {
    case principal
    case secundario
    case claro
}

public struct Accion: Codable, Sendable, Equatable {
    public var titulo: String
    public var destino: DestinoApp
    public var estilo: EstiloBoton
}

public struct Hero: Codable, Sendable, Equatable {
    public var sobre: String
    public var titulo: String
    public var entradilla: String
    public var parrafos: [String]
    public var acciones: [Accion]
}

public struct Cifra: Codable, Sendable, Equatable {
    public var valor: String
    public var detalle: String
    public var sello: Sello?
    public var ocr: Bool?
    public var meta: String?
    public var fuente: Fuente?
}

public struct Tarjeta: Codable, Sendable, Equatable {
    public var titulo: String
    public var texto: String
    public var meta: String?
    public var destino: DestinoApp?
    public var tituloDestino: String?
}

public struct CifraArchivo: Codable, Sendable, Equatable {
    public var valor: String
    public var etiqueta: String
    public var numero: Double
    public var meta: String
    public var fuente: Fuente
}

public struct ArchivoPublico: Codable, Sendable, Equatable {
    public var titulo: String
    public var introduccion: String
    public var cifras: [CifraArchivo]
    public var notaSinCopia: String
    public var graficoTitulo: String
    public var graficoNota: String
    public var grafico: [Barra]
}

public struct Seccion: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var titulo: String?
    public var bloques: [Bloque]
}

public struct Pagina: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var titulo: String
    public var secciones: [Seccion]
}

public struct Adjunto: Codable, Sendable, Equatable {
    public var ruta: String
    public var titulo: String
}

public struct Hilo: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var titulo: String
    public var fecha: String
    public var fechaISO: String
    public var tema: String
    public var resumen: String
    public var entradilla: String
    public var ruta: String
    public var destacados: [Cifra]
    public var fuente: Fuente
    public var adjunto: Adjunto?
    public var secciones: [Seccion]
}

public struct MomentoLibro: Codable, Sendable, Equatable {
    public var fecha: String
    public var iso: String
    public var texto: String
    public var ancla: String
}

public struct Capitulo: Codable, Sendable, Equatable, Identifiable {
    public var numero: Int
    public var ancla: String
    public var periodo: String
    public var titulo: String
    public var resumen: String
    public var enMuestra: Bool
    public var id: String { ancla }
}

public struct MuestraLibro: Codable, Sendable, Equatable {
    public var descripcion: String
    public var paginas: Int
    public var incluye: [String]
}

public struct Libro: Codable, Sendable, Equatable {
    public var titulo: String
    public var subtitulo: String
    public var autor: String
    public var meta: String
    public var fechaDatos: String
    public var entradilla: String
    public var parrafos: [String]
    public var pagaLoQueQuieras: String
    public var sugeridoUSD: Int
    public var pasos: [String]
    public var historia: [String]
    public var momentos: [MomentoLibro]
    public var antes: String
    public var capitulos: [Capitulo]
    public var comoEstaHecho: [String]
    public var avisoRedaccion: String
    public var paraQuien: [String]
    public var edicion: [String]
    public var muestra: MuestraLibro
    public var textoCompletoIncluido: Bool
    public var ruta: String
}

public struct EnlacesKoFi: Codable, Sendable, Equatable {
    public var apoyo: URL
    public var libro: URL
    public var muestra: URL

    public func url(_ cual: CualKoFi) -> URL {
        switch cual {
        case .apoyo: apoyo
        case .libro: libro
        case .muestra: muestra
        }
    }
}

public struct ContenidoLufy: Codable, Sendable, Equatable {
    public var version: Int
    public var actualizado: String
    public var enlaces: EnlacesKoFi
    public var archivo: ArchivoPublico
    public var inicio: Pagina
    public var datos: Pagina
    public var hilos: [Hilo]
    public var libro: Libro
    public var apoyo: Pagina
    public var historia: Pagina
    public var privacidad: Pagina
}
