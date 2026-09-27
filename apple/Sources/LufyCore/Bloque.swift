import Foundation

public enum Bloque: Sendable, Equatable {
    case prosa(parrafos: [String])
    case lista(items: [String], ordenada: Bool)
    case saber(titulo: String, items: [String])
    case cifras([Cifra])
    case grafico(Grafico)
    case comparaciones(Comparaciones)
    case tabla(Tabla)
    case aviso(String)
    case columnas(izquierda: ColumnaTexto, derecha: ColumnaTexto)
    case ficha([ParFicha])
    case glosario([EntradaGlosario])
    case tiempo([Evento])
    case documentos(intro: String, items: [DocumentoFuente])
    case leyenda([ItemLeyenda])
    case tarjetas([Tarjeta])
    case fuente(Fuente)
    case enlace(titulo: String, destino: DestinoApp)
    case botonKoFi(titulo: String, cual: CualKoFi)
    case metaCerebro
    case archivoPublico(titulo: String?)
    case listaHilos
    case hero(Hero)
}

extension Bloque: Codable {
    private enum Clave: String, CodingKey {
        case tipo
        case parrafos
        case items
        case ordenada
        case titulo
        case sobre
        case entradilla
        case acciones
        case cifras
        case nota
        case leyenda
        case barras
        case grupos
        case columnas
        case filas
        case texto
        case izquierda
        case derecha
        case pares
        case entradas
        case eventos
        case intro
        case destino
        case cual
        case fuente
    }

    public init(from decoder: Decoder) throws {
        let contenedor = try decoder.container(keyedBy: Clave.self)
        let tipo = try contenedor.decode(String.self, forKey: .tipo)
        switch tipo {
        case "prosa":
            self = .prosa(parrafos: try contenedor.decode([String].self, forKey: .parrafos))
        case "lista":
            self = .lista(
                items: try contenedor.decode([String].self, forKey: .items),
                ordenada: try contenedor.decodeIfPresent(Bool.self, forKey: .ordenada) ?? false
            )
        case "saber":
            self = .saber(
                titulo: try contenedor.decode(String.self, forKey: .titulo),
                items: try contenedor.decode([String].self, forKey: .items)
            )
        case "cifras":
            self = .cifras(try contenedor.decode([Cifra].self, forKey: .cifras))
        case "grafico":
            self = .grafico(try Grafico(from: decoder))
        case "comparaciones":
            self = .comparaciones(try Comparaciones(from: decoder))
        case "tabla":
            self = .tabla(try Tabla(from: decoder))
        case "aviso":
            self = .aviso(try contenedor.decode(String.self, forKey: .texto))
        case "columnas":
            self = .columnas(
                izquierda: try contenedor.decode(ColumnaTexto.self, forKey: .izquierda),
                derecha: try contenedor.decode(ColumnaTexto.self, forKey: .derecha)
            )
        case "ficha":
            self = .ficha(try contenedor.decode([ParFicha].self, forKey: .pares))
        case "glosario":
            self = .glosario(try contenedor.decode([EntradaGlosario].self, forKey: .entradas))
        case "tiempo":
            self = .tiempo(try contenedor.decode([Evento].self, forKey: .eventos))
        case "documentos":
            self = .documentos(
                intro: try contenedor.decode(String.self, forKey: .intro),
                items: try contenedor.decode([DocumentoFuente].self, forKey: .items)
            )
        case "leyenda":
            self = .leyenda(try contenedor.decode([ItemLeyenda].self, forKey: .items))
        case "tarjetas":
            self = .tarjetas(try contenedor.decode([Tarjeta].self, forKey: .items))
        case "fuente":
            self = .fuente(try contenedor.decode(Fuente.self, forKey: .fuente))
        case "enlace":
            self = .enlace(
                titulo: try contenedor.decode(String.self, forKey: .titulo),
                destino: try contenedor.decode(DestinoApp.self, forKey: .destino)
            )
        case "botonKoFi":
            self = .botonKoFi(
                titulo: try contenedor.decode(String.self, forKey: .titulo),
                cual: try contenedor.decode(CualKoFi.self, forKey: .cual)
            )
        case "metaCerebro":
            self = .metaCerebro
        case "archivoPublico":
            self = .archivoPublico(titulo: try contenedor.decodeIfPresent(String.self, forKey: .titulo))
        case "listaHilos":
            self = .listaHilos
        case "hero":
            self = .hero(try Hero(from: decoder))
        default:
            throw ErrorContenido.validacion("Bloque desconocido: \(tipo).")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var contenedor = encoder.container(keyedBy: Clave.self)
        switch self {
        case .prosa(let parrafos):
            try contenedor.encode("prosa", forKey: .tipo)
            try contenedor.encode(parrafos, forKey: .parrafos)
        case .lista(let items, let ordenada):
            try contenedor.encode("lista", forKey: .tipo)
            try contenedor.encode(items, forKey: .items)
            try contenedor.encode(ordenada, forKey: .ordenada)
        case .saber(let titulo, let items):
            try contenedor.encode("saber", forKey: .tipo)
            try contenedor.encode(titulo, forKey: .titulo)
            try contenedor.encode(items, forKey: .items)
        case .cifras(let cifras):
            try contenedor.encode("cifras", forKey: .tipo)
            try contenedor.encode(cifras, forKey: .cifras)
        case .grafico(let grafico):
            try contenedor.encode("grafico", forKey: .tipo)
            try contenedor.encode(grafico.titulo, forKey: .titulo)
            try contenedor.encode(grafico.nota, forKey: .nota)
            try contenedor.encodeIfPresent(grafico.leyenda, forKey: .leyenda)
            try contenedor.encode(grafico.barras, forKey: .barras)
        case .comparaciones(let comparaciones):
            try contenedor.encode("comparaciones", forKey: .tipo)
            try contenedor.encode(comparaciones.titulo, forKey: .titulo)
            try contenedor.encode(comparaciones.nota, forKey: .nota)
            try contenedor.encode(comparaciones.leyenda, forKey: .leyenda)
            try contenedor.encode(comparaciones.grupos, forKey: .grupos)
        case .tabla(let tabla):
            try contenedor.encode("tabla", forKey: .tipo)
            try contenedor.encode(tabla.titulo, forKey: .titulo)
            try contenedor.encode(tabla.columnas, forKey: .columnas)
            try contenedor.encode(tabla.filas, forKey: .filas)
            try contenedor.encodeIfPresent(tabla.nota, forKey: .nota)
        case .aviso(let texto):
            try contenedor.encode("aviso", forKey: .tipo)
            try contenedor.encode(texto, forKey: .texto)
        case .columnas(let izquierda, let derecha):
            try contenedor.encode("columnas", forKey: .tipo)
            try contenedor.encode(izquierda, forKey: .izquierda)
            try contenedor.encode(derecha, forKey: .derecha)
        case .ficha(let pares):
            try contenedor.encode("ficha", forKey: .tipo)
            try contenedor.encode(pares, forKey: .pares)
        case .glosario(let entradas):
            try contenedor.encode("glosario", forKey: .tipo)
            try contenedor.encode(entradas, forKey: .entradas)
        case .tiempo(let eventos):
            try contenedor.encode("tiempo", forKey: .tipo)
            try contenedor.encode(eventos, forKey: .eventos)
        case .documentos(let intro, let items):
            try contenedor.encode("documentos", forKey: .tipo)
            try contenedor.encode(intro, forKey: .intro)
            try contenedor.encode(items, forKey: .items)
        case .leyenda(let items):
            try contenedor.encode("leyenda", forKey: .tipo)
            try contenedor.encode(items, forKey: .items)
        case .tarjetas(let items):
            try contenedor.encode("tarjetas", forKey: .tipo)
            try contenedor.encode(items, forKey: .items)
        case .fuente(let fuente):
            try contenedor.encode("fuente", forKey: .tipo)
            try contenedor.encode(fuente, forKey: .fuente)
        case .enlace(let titulo, let destino):
            try contenedor.encode("enlace", forKey: .tipo)
            try contenedor.encode(titulo, forKey: .titulo)
            try contenedor.encode(destino, forKey: .destino)
        case .botonKoFi(let titulo, let cual):
            try contenedor.encode("botonKoFi", forKey: .tipo)
            try contenedor.encode(titulo, forKey: .titulo)
            try contenedor.encode(cual, forKey: .cual)
        case .metaCerebro:
            try contenedor.encode("metaCerebro", forKey: .tipo)
        case .archivoPublico(let titulo):
            try contenedor.encode("archivoPublico", forKey: .tipo)
            try contenedor.encodeIfPresent(titulo, forKey: .titulo)
        case .listaHilos:
            try contenedor.encode("listaHilos", forKey: .tipo)
        case .hero(let hero):
            try contenedor.encode("hero", forKey: .tipo)
            try contenedor.encode(hero.sobre, forKey: .sobre)
            try contenedor.encode(hero.titulo, forKey: .titulo)
            try contenedor.encode(hero.entradilla, forKey: .entradilla)
            try contenedor.encode(hero.parrafos, forKey: .parrafos)
            try contenedor.encode(hero.acciones, forKey: .acciones)
        }
    }
}
