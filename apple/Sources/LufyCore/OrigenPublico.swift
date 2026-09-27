import Foundation

/// Dirección del sitio público. El nombre que ve la persona es Lufy.
/// Esta URL solo sirve para descargar el índice y las copias archivadas.
public enum OrigenPublico {
    public static let sitio = URL(string: "https://dimolinari.github.io/lufy-web/")!
    public static let rutaContenido = "data/contenido.json"
    public static let rutaMeta = "data/meta.json"

    public static func url(_ ruta: String) -> URL? {
        if ruta.isEmpty || ruta == "index.html" {
            return sitio
        }
        return PoliticaEnlaces.urlLufy(ruta: ruta, origen: sitio)
    }
}
