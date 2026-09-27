import Foundation

public enum ErrorContenido: Error, Equatable, Sendable, LocalizedError {
    case recursoAusente(String)
    case jsonInvalido(String)
    case metaInvalida
    case libroCompletoProhibido
    case red
    case validacion(String)

    public var errorDescription: String? {
        switch self {
        case .recursoAusente(let nombre):
            return "Falta el recurso \(nombre)."
        case .jsonInvalido:
            return "El índice de Lufy no se pudo leer."
        case .metaInvalida:
            return "No se pudo leer la cifra de la meta."
        case .libroCompletoProhibido:
            return "El libro completo no se publica en la app."
        case .red:
            return "No se pudo descargar el contenido."
        case .validacion(let mensaje):
            return mensaje
        }
    }
}
