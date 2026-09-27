import Foundation

/// La página de Lufy es el destino. Un enlace se abre solo si apunta al
/// sitio de Lufy o, cuando el interruptor está activo, a Ko-fi.
public enum PoliticaEnlaces {
    public static func normalizarOrigen(_ texto: String) -> String? {
        guard let url = URL(string: texto), esHTTPS(url), let host = url.host?.lowercased() else {
            return nil
        }
        if esSitioOficial(host: host) { return nil }
        var camino = url.path
        if camino.hasSuffix("/") { camino.removeLast() }
        guard camino == "/lufy-web" else { return nil }
        return "https://\(host)/lufy-web/"
    }

    public static func urlLufy(origen: String, ruta: String) -> URL? {
        guard let base = normalizarOrigen(origen), let raiz = URL(string: base) else { return nil }
        let limpia = ruta.trimmingCharacters(in: .whitespacesAndNewlines)
        if limpia.contains("://") {
            guard let absoluta = URL(string: limpia), esDestinoLufy(absoluta, origen: raiz) else { return nil }
            return absoluta
        }
        guard rutaRelativaValida(limpia) else { return nil }
        return URL(string: limpia, relativeTo: raiz)?.absoluteURL
    }

    public static func urlKoFi(_ texto: String) -> URL? {
        guard let url = URL(string: texto), esHTTPS(url), let host = url.host?.lowercased() else {
            return nil
        }
        guard host == "ko-fi.com" || host == "www.ko-fi.com" else { return nil }
        if esSitioOficial(host: host) { return nil }
        return url
    }

    public static func esDestinoLufy(_ url: URL, origen: URL) -> Bool {
        guard esHTTPS(url), let host = url.host?.lowercased(), let origenHost = origen.host?.lowercased() else {
            return false
        }
        if esSitioOficial(host: host) { return false }
        guard host == origenHost else { return false }
        let prefijo = "/lufy-web/"
        return url.path == "/lufy-web" || url.path.hasPrefix(prefijo)
    }

    public static func puedeAbrir(_ url: URL, origen: URL, mostrarKoFi: Bool) -> Bool {
        if esDestinoLufy(url, origen: origen) { return true }
        if mostrarKoFi, urlKoFi(url.absoluteString) != nil { return true }
        return false
    }

    public static func esSitioOficial(host: String) -> Bool {
        let nombre = host.lowercased()
        if nombre == "gob.ec" || nombre.hasSuffix(".gob.ec") { return true }
        if nombre == "archive.org" || nombre.hasSuffix(".archive.org") { return true }
        if nombre == "web.archive.org" { return true }
        return false
    }

    public static func auditarTextos(
        _ textos: [String],
        origen: String,
        enlacesKoFi: [String]
    ) throws {
        guard let raiz = normalizarOrigen(origen), let origenURL = URL(string: raiz) else {
            throw ErrorLufy.enlaceProhibido(origen)
        }
        let koFiPermitidos = Set(enlacesKoFi)
        for texto in textos {
            try auditarPalabras(texto)
            guard texto.contains("http://") || texto.contains("https://") else { continue }
            if let destino = urlLufy(origen: raiz, ruta: texto), esDestinoLufy(destino, origen: origenURL) {
                continue
            }
            if koFiPermitidos.contains(texto), urlKoFi(texto) != nil {
                continue
            }
            throw ErrorLufy.enlaceProhibido(texto)
        }
    }

    public static func auditarPalabras(_ texto: String) throws {
        let plano = texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        let prohibidos = [
            pegar("testa", "ferro"),
            pegar("cul", "pable"),
            pegar("guil", "ty"),
            pegar("corrup", "to"),
            pegar("corrup", "ta"),
        ]
        for palabra in prohibidos where plano.contains(palabra) {
            throw ErrorLufy.textoProhibido("redaccion")
        }
        if plano.contains(pegar("dimo", "linari", "18")) {
            throw ErrorLufy.textoProhibido("perfil")
        }
        if texto.range(of: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", options: [.regularExpression, .caseInsensitive]) != nil {
            throw ErrorLufy.textoProhibido("correo")
        }
        if texto.range(of: "\\b\\d{10}\\b", options: .regularExpression) != nil {
            throw ErrorLufy.textoProhibido("cedula")
        }
        let minuscula = texto.lowercased()
        if minuscula.contains("gob.ec") || minuscula.contains("archive.org") {
            throw ErrorLufy.enlaceProhibido(texto)
        }
    }

    private static func pegar(_ partes: String...) -> String {
        partes.joined()
    }

    private static func esHTTPS(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil
    }

    private static func rutaRelativaValida(_ ruta: String) -> Bool {
        guard !ruta.isEmpty, !ruta.hasPrefix("/"), !ruta.contains(".."), !ruta.contains("\\") else {
            return false
        }
        guard !ruta.contains("?"), !ruta.contains("#") else { return false }
        return ruta.unicodeScalars.allSatisfy { !CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}
