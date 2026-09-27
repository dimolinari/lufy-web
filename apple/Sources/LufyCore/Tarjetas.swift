import Foundation

/// Datos de una tarjeta. El texto sale de lo publicado: título, fuente y,
/// si el ítem lo trae, el sello tal cual. Un voto y un gráfico no inventan sello.
public struct TarjetaCompartible: Sendable, Equatable {
    public let titulo: String
    public let texto: String
    public let sello: Sello?
    public let lineaFuente: String
    public let url: URL

    public static let pixelesAncho = 1080
    public static let pixelesAlto = 1920
    public static let escala = 3
}

public enum TarjetasLufy {
    public static func armar(
        titulo: String,
        texto: String,
        sello: Sello?,
        lineaFuente: String,
        origen: String,
        ruta: String
    ) throws -> TarjetaCompartible {
        let tituloLimpio = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        let textoLimpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        let linea = lineaFuente.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tituloLimpio.isEmpty, !textoLimpio.isEmpty, !linea.isEmpty else {
            throw ErrorLufy.contenidoIncompleto("tarjeta")
        }
        try PoliticaEnlaces.auditarPalabras(tituloLimpio)
        try PoliticaEnlaces.auditarPalabras(textoLimpio)
        try PoliticaEnlaces.auditarPalabras(linea)
        guard let url = PoliticaEnlaces.urlLufy(origen: origen, ruta: ruta) else {
            throw ErrorLufy.enlaceProhibido(ruta)
        }
        return TarjetaCompartible(
            titulo: tituloLimpio,
            texto: textoLimpio,
            sello: sello,
            lineaFuente: linea,
            url: url
        )
    }

    public static func hallazgo(
        _ hallazgo: HallazgoPublico,
        origen: String,
        ruta: String
    ) throws -> TarjetaCompartible {
        try armar(
            titulo: hallazgo.titulo,
            texto: hallazgo.texto,
            sello: hallazgo.sello,
            lineaFuente: hallazgo.fuente.linea,
            origen: origen,
            ruta: ruta
        )
    }

    public static func cifra(_ cifra: Cifra, origen: String, ruta: String) throws -> TarjetaCompartible {
        try armar(
            titulo: cifra.valor,
            texto: cifra.detalle,
            sello: cifra.sello,
            lineaFuente: cifra.fuente.linea,
            origen: origen,
            ruta: ruta
        )
    }

    public static func grafico(_ grafico: Grafico, origen: String, ruta: String) throws -> TarjetaCompartible {
        let linea = grafico.fuente?.linea ?? grafico.nota
        var partes: [String] = []
        if grafico.fuente != nil, !grafico.nota.isEmpty {
            partes.append(grafico.nota)
        }
        for grupo in grafico.grupos {
            if !grupo.nombre.isEmpty {
                partes.append(grupo.nombre)
            }
            for barra in grupo.barras {
                partes.append("\(barra.etiqueta) \(barra.texto)")
            }
        }
        let cuerpo = partes.joined(separator: "\n")
        return try armar(
            titulo: grafico.titulo,
            texto: cuerpo.isEmpty ? grafico.titulo : cuerpo,
            sello: nil,
            lineaFuente: linea,
            origen: origen,
            ruta: ruta
        )
    }

    public static func voto(
        nombre: String,
        votacion: Votacion,
        sentido: SentidoVoto,
        origen: String,
        ruta: String
    ) throws -> TarjetaCompartible {
        try armar(
            titulo: votacion.titulo,
            texto: "\(nombre): \(sentido.etiqueta)",
            sello: nil,
            lineaFuente: votacion.fuente.linea,
            origen: origen,
            ruta: ruta
        )
    }
}
