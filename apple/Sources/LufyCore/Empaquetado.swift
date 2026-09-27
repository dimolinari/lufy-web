import Foundation

public enum ContenidoEmpaquetado {
    public static func datosContenido() throws -> Data {
        try datos(nombre: "contenido", extension: "json")
    }

    public static func datosMeta() throws -> Data {
        try datos(nombre: "meta", extension: "json")
    }

    /// Copia incluida para el primer arranque sin red. El nombre es el archivo
    /// de la ruta publicada en Lufy, sin carpetas.
    public static func datosAdjunto(ruta: String) -> Data? {
        guard PoliticaEnlaces.rutaSegura(ruta) else { return nil }
        let archivo = URL(fileURLWithPath: ruta)
        let nombre = archivo.deletingPathExtension().lastPathComponent
        let ext = archivo.pathExtension
        guard !nombre.isEmpty, !ext.isEmpty, !nombre.contains("/") else { return nil }
        guard let url = Bundle.module.url(forResource: nombre, withExtension: ext) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func datos(nombre: String, extension ext: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: nombre, withExtension: ext) else {
            throw ErrorContenido.recursoAusente("\(nombre).\(ext)")
        }
        return try Data(contentsOf: url)
    }
}
