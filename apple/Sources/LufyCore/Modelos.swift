import Foundation

public enum Sello: String, Codable, Sendable, Equatable, CaseIterable {
    case confirmado = "CONFIRMADO"
    case indicio = "INDICIO"
    case abierto = "ABIERTO"
    case hipotesis = "HIPÓTESIS"
}

public enum TonoBarra: String, Decodable, Sendable, Equatable {
    case oro
    case oroRaya
    case vino
    case vinoRaya
    case tinta
    case punto
}

public enum EscalaGrafico: String, Decodable, Sendable, Equatable {
    case compartida
    case porGrupo
}

public struct MetaRecaudacion: Decodable, Sendable, Equatable {
    public let goalUSD: Double
    public let raisedUSD: Double
    public let updated: String

    private enum CodingKeys: String, CodingKey {
        case goalUSD = "goal_usd"
        case raisedUSD = "raised_usd"
        case updated
    }

    public var textoCifra: String {
        "\(Formato.dolarMeta(raisedUSD)) de \(Formato.dolarMeta(goalUSD))"
    }

    public var fraccion: Double {
        guard goalUSD > 0 else { return 0 }
        return min(1, max(0, raisedUSD / goalUSD))
    }

    public var textoFecha: String {
        "Actualizado: \(updated)"
    }

    public func validar() throws {
        guard goalUSD.isFinite, goalUSD > 0 else { throw ErrorLufy.metaInvalida("meta") }
        guard raisedUSD.isFinite, raisedUSD >= 0 else { throw ErrorLufy.metaInvalida("recaudado") }
        guard Fechas.isoValida(updated) else { throw ErrorLufy.fechaInvalida(updated) }
    }
}

public struct CopiaArchivada: Decodable, Sendable, Equatable {
    public let ruta: String
    public let sha256: String
    public let archivado: String

    public func validar(origen: String) throws {
        guard sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw ErrorLufy.archivoInvalido("huella")
        }
        guard Fechas.isoValida(archivado) else { throw ErrorLufy.fechaInvalida(archivado) }
        guard PoliticaEnlaces.urlLufy(origen: origen, ruta: ruta) != nil else {
            throw ErrorLufy.enlaceProhibido(ruta)
        }
    }
}

public struct Fuente: Decodable, Sendable, Equatable {
    public let institucion: String
    public let documento: String
    public let fecha: String
    public let linea: String
    public let archivo: CopiaArchivada?

    public func validar(origen: String) throws {
        guard !institucion.isEmpty, !documento.isEmpty, !linea.isEmpty else {
            throw ErrorLufy.contenidoIncompleto("fuente")
        }
        guard Fechas.isoValida(fecha) else { throw ErrorLufy.fechaInvalida(fecha) }
        try archivo?.validar(origen: origen)
    }
}

public struct Cifra: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let meta: String?
    public let sello: Sello?
    public let ocr: Bool
    public let valor: String
    public let numero: Double?
    public let detalle: String
    public let fuente: Fuente
}

public struct LeyendaItem: Decodable, Sendable, Equatable, Identifiable {
    public let tono: TonoBarra
    public let etiqueta: String
    public var id: String { etiqueta }
}

public struct Barra: Decodable, Sendable, Equatable, Identifiable {
    public let etiqueta: String
    public let valor: Double
    public let texto: String
    public let tono: TonoBarra
    public var id: String { etiqueta }
}

public struct GrupoBarras: Decodable, Sendable, Equatable, Identifiable {
    public let nombre: String
    public let ocr: Bool
    public let barras: [Barra]
    public var id: String { nombre }
}

public struct Grafico: Decodable, Sendable, Equatable {
    public let titulo: String
    public let nota: String
    public let escala: EscalaGrafico
    public let leyenda: [LeyendaItem]
    public let grupos: [GrupoBarras]
    public let fuente: Fuente?

    public func fraccion(grupo: GrupoBarras, barra: Barra) -> Double {
        let valores: [Double]
        switch escala {
        case .compartida:
            valores = grupos.flatMap(\.barras).map(\.valor)
        case .porGrupo:
            valores = grupo.barras.map(\.valor)
        }
        let maximo = valores.max() ?? 0
        guard maximo > 0 else { return 0 }
        return min(1, max(0, barra.valor / maximo))
    }

    /// Ancho del relleno. Una fracción de 0 o menos mide 0; un valor
    /// positivo conserva `minimoVisible` para que el trazo no desaparezca.
    public static func anchoRelleno(fraccion: Double, anchoPista: Double, minimoVisible: Double = 4) -> Double {
        guard fraccion > 0 else { return 0 }
        return max(minimoVisible, anchoPista * fraccion)
    }
}

public struct ColumnaTabla: Decodable, Sendable, Equatable, Identifiable {
    public let titulo: String
    public let numerica: Bool
    public var id: String { titulo }
}

public struct FilaTabla: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let celdas: [String]
    public let ocr: Bool
}

public struct Tabla: Decodable, Sendable, Equatable {
    public let titulo: String
    public let columnas: [ColumnaTabla]
    public let filas: [FilaTabla]
    public let nota: String?
    public let fuente: Fuente?
}

public struct Prosa: Decodable, Sendable, Equatable {
    public let titulo: String
    public let parrafos: [String]
    public let fuente: Fuente?
}

public struct Aviso: Decodable, Sendable, Equatable {
    public let texto: String
}

public struct Lista: Decodable, Sendable, Equatable {
    public let titulo: String
    public let items: [String]
    public let fuente: Fuente?
}

public struct Columna: Decodable, Sendable, Equatable {
    public let titulo: String
    public let items: [String]
}

public struct Columnas: Decodable, Sendable, Equatable {
    public let titulo: String
    public let izquierda: Columna
    public let derecha: Columna
}

public struct Hito: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let fecha: String
    public let etiqueta: String
    public let texto: String
}

public struct Tiempo: Decodable, Sendable, Equatable {
    public let titulo: String
    public let introduccion: String?
    public let hitos: [Hito]
    public let fuente: Fuente?
}

public struct ParFicha: Decodable, Sendable, Equatable, Identifiable {
    public let etiqueta: String
    public let valor: String
    public var id: String { etiqueta }
}

public struct Ficha: Decodable, Sendable, Equatable {
    public let titulo: String
    public let pares: [ParFicha]
    public let notas: [String]
}

public struct Termino: Decodable, Sendable, Equatable, Identifiable {
    public let termino: String
    public let definicion: String
    public var id: String { termino }
}

public struct Glosario: Decodable, Sendable, Equatable {
    public let titulo: String
    public let terminos: [Termino]
}

public struct Documento: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let institucion: String
    public let titulo: String
    public let fuente: Fuente
}

public struct Documentos: Decodable, Sendable, Equatable {
    public let titulo: String
    public let introduccion: String
    public let items: [Documento]
    public let csv: String?
}

public struct Cambio: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let fecha: String
    public let etiqueta: String
    public let texto: String
}

public struct Cambios: Decodable, Sendable, Equatable {
    public let titulo: String
    public let items: [Cambio]
    public let cierre: String?
}

public enum Bloque: Decodable, Sendable, Equatable {
    case prosa(Prosa)
    case aviso(String)
    case lista(Lista)
    case grafico(Grafico)
    case tabla(Tabla)
    case columnas(Columnas)
    case tiempo(Tiempo)
    case ficha(Ficha)
    case glosario(Glosario)
    case documentos(Documentos)
    case cambios(Cambios)
    case desconocido

    private enum Key: String, CodingKey {
        case tipo
        case texto
    }

    public init(from decoder: Decoder) throws {
        let contenedor = try decoder.container(keyedBy: Key.self)
        let tipo = try contenedor.decode(String.self, forKey: .tipo)
        switch tipo {
        case "prosa":
            self = .prosa(try Prosa(from: decoder))
        case "aviso":
            self = .aviso(try contenedor.decode(String.self, forKey: .texto))
        case "lista":
            self = .lista(try Lista(from: decoder))
        case "grafico":
            self = .grafico(try Grafico(from: decoder))
        case "tabla":
            self = .tabla(try Tabla(from: decoder))
        case "columnas":
            self = .columnas(try Columnas(from: decoder))
        case "tiempo":
            self = .tiempo(try Tiempo(from: decoder))
        case "ficha":
            self = .ficha(try Ficha(from: decoder))
        case "glosario":
            self = .glosario(try Glosario(from: decoder))
        case "documentos":
            self = .documentos(try Documentos(from: decoder))
        case "cambios":
            self = .cambios(try Cambios(from: decoder))
        default:
            self = .desconocido
        }
    }
}

public struct NotaLectura: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let sello: Sello?
    public let ocr: Bool
    public let texto: String
}

public struct TarjetaTexto: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let texto: String
}

public struct Principio: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let texto: String
    public let sellos: [Sello]
}

public struct FormaApoyo: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let parrafos: [String]
    public let boton: String?
    public let botonSecundario: String?
}

public struct Inicio: Decodable, Sendable, Equatable {
    public let sobre: String
    public let titulo: String
    public let entradilla: String
    public let apoyo: String
    public let pasos: [String]
    public let usos: [TarjetaTexto]
    public let formas: [FormaApoyo]
    public let principios: [Principio]
    public let destacado: String
}

public struct Archivo: Decodable, Sendable, Equatable {
    public let titulo: String
    public let tituloApoyo: String
    public let introduccion: String
    public let introduccionApoyo: String
    public let corte: String
    public let cifras: [Cifra]
    public let nota: String
    public let notaGraficoApoyo: String
    public let grafico: Grafico
}

public struct IndiceDatos: Decodable, Sendable, Equatable {
    public let titulo: String
    public let entradilla: String
    public let lectura: [NotaLectura]
    public let proximos: String
    public let rutaWeb: String
}

public struct Hilo: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let fecha: String
    public let tema: String
    public let entradilla: String
    public let extracto: String
    public let resumen: [String]
    public let lectura: [NotaLectura]
    public let cifras: [Cifra]
    public let bloques: [Bloque]
    public let fuenteTarjeta: Fuente
    public let rutaWeb: String
    public let textoCompartir: String
}

public struct CapituloLibro: Decodable, Sendable, Equatable, Identifiable {
    public let numero: Int
    public let periodo: String
    public let titulo: String
    public let resumen: String
    public var id: Int { numero }
}

public struct Libro: Decodable, Sendable, Equatable {
    public let sobre: String
    public let titulo: String
    public let subtitulo: String
    public let ficha: String
    public let entradilla: String
    public let pago: String
    public let pasos: [String]
    public let historiaTitulo: String
    public let historia: [String]
    public let lineaTitulo: String
    public let lineaIntro: String
    public let linea: [Hito]
    public let capitulosTitulo: String
    public let capitulosIntro: String
    public let antesDeEmpezar: String
    public let capitulos: [CapituloLibro]
    public let hechoTitulo: String
    public let hecho: [String]
    public let aviso: String
    public let paraQuienTitulo: String
    public let paraQuien: [String]
    public let edicionTitulo: String
    public let edicion: [String]
    public let muestraTitulo: String
    public let muestra: [String]
    public let precioSugeridoUSD: Int
    public let paginas: Int
    public let cantidadCapitulos: Int
    public let rutaWeb: String
    public let textoCompartir: String
}

public struct Apoyo: Decodable, Sendable, Equatable {
    public let sobre: String
    public let titulo: String
    public let entradilla: String
    public let porque: [String]
    public let usosIntro: String
    public let usos: [TarjetaTexto]
    public let formasTitulo: String
    public let formas: [FormaApoyo]
    public let principiosTitulo: String
    public let principios: [Principio]
    public let pie: String
    public let metaTitulo: String
    public let metaSobre: String
    public let metaParrafos: [String]
    public let metaNota: String
    public let rutaWeb: String
}

public struct SeccionTexto: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let parrafos: [String]
}

public struct Historia: Decodable, Sendable, Equatable {
    public let titulo: String
    public let entradilla: String
    public let secciones: [SeccionTexto]
    public let sellos: [NotaLectura]
    public let reglas: [String]
    public let fuentes: [String]
    public let notaFuentes: String
    public let correcciones: [Cambio]
    public let introCorrecciones: String
    public let contacto: String
    public let hiloMencionado: String?
    public let rutaWeb: String
}

public struct PuntoPrivacidad: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titulo: String
    public let texto: String
}

public struct AvisoPrivacidad: Decodable, Sendable, Equatable {
    public let titulo: String
    public let actualizado: String
    public let etiquetaActualizado: String
    public let puntos: [PuntoPrivacidad]
    public let rutaWeb: String
}

public struct Enlaces: Decodable, Sendable, Equatable {
    public let kofi: String
    public let libro: String
    public let muestra: String

    public var todos: [String] { [kofi, libro, muestra] }
}

public struct Catalogo: Decodable, Sendable, Equatable {
    public let schema: Int
    public let actualizado: String
    public let origen: String
    public let notaSinCopia: String
    public let textoCompartir: String
    public let inicio: Inicio
    public let archivo: Archivo
    public let datos: IndiceDatos
    public let hilos: [Hilo]
    public let libro: Libro
    public let apoyo: Apoyo
    public let historia: Historia
    public let privacidad: AvisoPrivacidad
    public let enlaces: Enlaces

    public func hilo(id: String) -> Hilo? {
        hilos.first { $0.id == id }
    }
}
