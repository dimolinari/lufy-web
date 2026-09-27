import Foundation

/// Los documentos solo se abren en el sitio de Lufy.
/// Ko-fi es el único otro host, y solo si el interruptor de compra está encendido.
public enum PoliticaEnlaces {
    public static func rutaSegura(_ ruta: String) -> Bool {
        guard !ruta.isEmpty,
              !ruta.hasPrefix("/"),
              !ruta.hasPrefix("."),
              !ruta.contains(".."),
              !ruta.contains("//"),
              !ruta.contains(":"),
              !ruta.contains("\\"),
              !ruta.contains("?"),
              !ruta.contains("#"),
              !ruta.contains(" ")
        else { return false }
        let permitidos = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/._-")
        return ruta.unicodeScalars.allSatisfy { permitidos.contains($0) }
    }

    public static func esLufy(_ url: URL, origen: URL = OrigenPublico.sitio) -> Bool {
        guard url.scheme == "https", url.host == origen.host, url.user == nil else { return false }
        let crudo = origen.path
        let prefijo = crudo.hasSuffix("/") ? String(crudo.dropLast()) : crudo
        guard !prefijo.isEmpty else { return false }
        return url.path == prefijo || url.path.hasPrefix(prefijo + "/")
    }

    public static func urlLufy(ruta: String, origen: URL = OrigenPublico.sitio) -> URL? {
        guard rutaSegura(ruta) else { return nil }
        let baseTexto = origen.absoluteString.hasSuffix("/") ? origen.absoluteString : origen.absoluteString + "/"
        guard let base = URL(string: baseTexto) else { return nil }
        guard let absoluto = URL(string: ruta, relativeTo: base)?.absoluteURL else { return nil }
        guard esLufy(absoluto, origen: origen) else { return nil }
        return absoluto
    }

    public static func urlKoFi(_ url: URL) -> URL? {
        guard url.scheme == "https", url.host == "ko-fi.com", url.user == nil else { return nil }
        return url
    }

    public static func urlPermitida(_ url: URL) -> Bool {
        esLufy(url) || urlKoFi(url) != nil
    }
}
