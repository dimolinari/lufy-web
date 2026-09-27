import Foundation

public enum DecodificadorContenido {
    public static func decodificar(_ datos: Data) throws -> ContenidoLufy {
        let contenido: ContenidoLufy
        do {
            contenido = try JSONDecoder().decode(ContenidoLufy.self, from: datos)
        } catch let error as ErrorContenido {
            throw error
        } catch {
            throw ErrorContenido.jsonInvalido(String(describing: error))
        }
        try Auditoria.validar(contenido, datos: datos)
        return contenido
    }
}
