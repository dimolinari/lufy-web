import Foundation

public enum EstiloTexto: Sendable, Equatable {
    case normal
    case fuerte
    case enfasis
}

public struct FragmentoTexto: Sendable, Equatable {
    public var estilo: EstiloTexto
    public var texto: String
}

public enum TextoMarcado {
    /// `**fuerte**` y `_énfasis_`. No interpreta enlaces.
    public static func fragmentos(_ fuente: String) -> [FragmentoTexto] {
        var resultado: [FragmentoTexto] = []
        var buffer = ""
        var estilo = EstiloTexto.normal
        var indice = fuente.startIndex

        func volcar() {
            if !buffer.isEmpty {
                resultado.append(FragmentoTexto(estilo: estilo, texto: buffer))
                buffer.removeAll(keepingCapacity: true)
            }
        }

        while indice < fuente.endIndex {
            if fuente[indice...].hasPrefix("**") {
                volcar()
                estilo = estilo == .fuerte ? .normal : .fuerte
                indice = fuente.index(indice, offsetBy: 2)
                continue
            }
            if fuente[indice] == "_" {
                volcar()
                estilo = estilo == .enfasis ? .normal : .enfasis
                indice = fuente.index(after: indice)
                continue
            }
            buffer.append(fuente[indice])
            indice = fuente.index(after: indice)
        }
        volcar()
        return resultado
    }
}
