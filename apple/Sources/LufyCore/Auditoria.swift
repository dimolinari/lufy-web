import Foundation

public enum Auditoria {
    public static let raicesProhibidas = ["testaferro", "corrupt", "culpable"]
    private static let clavesProhibidas: Set<String> = ["textoCompleto", "cuerpo", "capituloCompleto", "cedula", "cédula"]

    public static func validar(_ contenido: ContenidoLufy, datos: Data) throws {
        guard contenido.version == 1 else {
            throw ErrorContenido.validacion("La versión del índice no es compatible.")
        }
        guard Fechas.isoValida(contenido.actualizado) else {
            throw ErrorContenido.validacion("La fecha del índice no es válida.")
        }
        guard contenido.libro.textoCompletoIncluido == false else {
            throw ErrorContenido.libroCompletoProhibido
        }
        guard contenido.libro.autor == "Lufy" else {
            throw ErrorContenido.validacion("El libro se publica a nombre de Lufy.")
        }
        guard contenido.libro.capitulos.count == 14 else {
            throw ErrorContenido.validacion("El libro tiene 14 capítulos.")
        }
        let enMuestra = contenido.libro.capitulos.filter(\.enMuestra).map(\.numero)
        guard enMuestra == [8] else {
            throw ErrorContenido.validacion("La muestra pública es el capítulo 8.")
        }
        guard contenido.hilos.isEmpty == false else {
            throw ErrorContenido.validacion("No hay hilos de datos.")
        }
        let ids = contenido.hilos.map(\.id)
        guard Set(ids).count == ids.count else {
            throw ErrorContenido.validacion("Hay hilos con el mismo identificador.")
        }
        for enlace in [contenido.enlaces.apoyo, contenido.enlaces.libro, contenido.enlaces.muestra] {
            guard PoliticaEnlaces.urlKoFi(enlace) != nil else {
                throw ErrorContenido.validacion("Un enlace de Ko-fi no está permitido.")
            }
        }
        for hilo in contenido.hilos {
            guard Fechas.isoValida(hilo.fechaISO) else {
                throw ErrorContenido.validacion("La fecha de un hilo no es válida.")
            }
            guard PoliticaEnlaces.urlLufy(ruta: hilo.ruta) != nil else {
                throw ErrorContenido.validacion("La ruta de un hilo no es de Lufy.")
            }
            if let adjunto = hilo.adjunto, PoliticaEnlaces.urlLufy(ruta: adjunto.ruta) == nil {
                throw ErrorContenido.validacion("Un adjunto no está alojado en Lufy.")
            }
        }
        guard PoliticaEnlaces.urlLufy(ruta: contenido.libro.ruta) != nil else {
            throw ErrorContenido.validacion("La ruta del libro no es de Lufy.")
        }
        guard Fechas.isoValida(contenido.libro.fechaDatos) else {
            throw ErrorContenido.validacion("La fecha de datos del libro no es válida.")
        }

        let objeto = try JSONSerialization.jsonObject(with: datos)
        try recorrer(objeto)
    }

    private static func recorrer(_ valor: Any) throws {
        if let texto = valor as? String {
            try revisarTexto(texto)
            return
        }
        if let diccionario = valor as? [String: Any] {
            for clave in diccionario.keys where Auditoria.clavesProhibidas.contains(clave) {
                throw ErrorContenido.validacion("El índice incluye un campo que no se publica.")
            }
            if let marca = diccionario["marca"] as? String, marca != "OCR" {
                throw ErrorContenido.validacion("Marca desconocida.")
            }
            if let archivo = diccionario["archivo"] as? [String: Any],
               archivo["sha256"] != nil || archivo["ruta"] != nil {
                try revisarArchivo(archivo)
            }
            if let sha = diccionario["sha256"] as? String {
                guard HuellaSHA256.esValida(sha) else {
                    throw ErrorContenido.validacion("Hay una huella SHA-256 que no es válida.")
                }
            }
            if let iso = diccionario["iso"] as? String {
                let soloAnio = iso.range(of: #"^\d{4}$"#, options: .regularExpression) != nil
                guard soloAnio || Fechas.isoValida(iso) else {
                    throw ErrorContenido.validacion("Hay una fecha ISO que no es válida.")
                }
            }
            if let archivado = diccionario["archivado"] as? String {
                guard Fechas.isoValida(archivado) else {
                    throw ErrorContenido.validacion("La fecha de archivo no es válida.")
                }
            }
            for valor in diccionario.values {
                try recorrer(valor)
            }
            return
        }
        if let lista = valor as? [Any] {
            for valor in lista {
                try recorrer(valor)
            }
        }
    }

    private static func revisarArchivo(_ archivo: [String: Any]) throws {
        guard let ruta = archivo["ruta"] as? String, PoliticaEnlaces.rutaSegura(ruta),
              PoliticaEnlaces.urlLufy(ruta: ruta) != nil
        else {
            throw ErrorContenido.validacion("Una copia archivada no apunta a Lufy.")
        }
        guard let sha = archivo["sha256"] as? String, HuellaSHA256.esValida(sha) else {
            throw ErrorContenido.validacion("Una copia archivada no trae huella SHA-256.")
        }
        guard let fecha = archivo["archivado"] as? String, Fechas.isoValida(fecha) else {
            throw ErrorContenido.validacion("Una copia archivada no trae fecha.")
        }
    }

    private static func revisarTexto(_ texto: String) throws {
        let plano = texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        for raiz in raicesProhibidas where plano.contains(raiz) {
            throw ErrorContenido.validacion("El índice incluye una palabra que Lufy no publica.")
        }
        if texto.range(of: #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#, options: [.regularExpression, .caseInsensitive]) != nil {
            throw ErrorContenido.validacion("El índice incluye un correo.")
        }
        if texto.range(of: #"(?<![A-Za-z0-9])[0-9]{10}(?![A-Za-z0-9])"#, options: .regularExpression) != nil {
            throw ErrorContenido.validacion("El índice incluye un número que parece una cédula.")
        }
        if plano.contains("gob.ec") {
            throw ErrorContenido.validacion("El índice enlaza un sitio oficial.")
        }
        guard let expresion = try? NSRegularExpression(pattern: "https?://[^\\s\\]\"'<>]+") else { return }
        let rango = NSRange(texto.startIndex..., in: texto)
        for coincidencia in expresion.matches(in: texto, range: rango) {
            guard let rangoURL = Range(coincidencia.range, in: texto) else { continue }
            var crudo = String(texto[rangoURL])
            while let ultimo = crudo.last, ".,);".contains(ultimo) {
                crudo.removeLast()
            }
            guard let url = URL(string: crudo) else {
                throw ErrorContenido.validacion("Hay un enlace que no se puede leer.")
            }
            guard PoliticaEnlaces.urlPermitida(url) else {
                throw ErrorContenido.validacion("Hay un enlace fuera de Lufy.")
            }
        }
    }
}
