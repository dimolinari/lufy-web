import Foundation
import LufyCore

/// Interruptor único de los enlaces de aporte y de compra.
/// Las compilaciones locales lo dejan encendido. Antes de un envío a la
/// App Store hay que leer `apple/README.md`: en Estados Unidos las reglas
/// de enlaces de compra externos pueden exigir apagarlo.
enum Configuracion {
    static let mostrarEnlacesKoFi = true

    /// Capa de pago. Apagada: nada se esconde y no hay compras ni avisos.
    /// El contenido de base sigue gratis con el interruptor en cualquiera de los dos lados.
    static let capaDePagoActiva = false

    /// Convención del publicador (N días) al escribir `early_access_until`.
    /// La app no suma estos días: obedece la fecha del feed.
    static let diasAccesoAnticipado = AccesoTemprano.diasPorDefecto

    /// Buzón del botón «Solicitar corrección». Las dos partes son un dominio
    /// de ejemplo: cámbialas por el buzón de Lufy antes de publicar.
    static var correoCorrecciones: String {
        ["correcciones", "lufy.example"].joined(separator: "@")
    }

    static func urlCorreccion(perfil: String) -> URL? {
        guard perfil.range(of: "^[a-z0-9-]{1,64}$", options: .regularExpression) != nil else { return nil }
        let asunto = "Corrección de perfil \(perfil)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let cuerpo = "id: \(perfil)\ncampo: nombre\n"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(correoCorrecciones)?subject=\(asunto)&body=\(cuerpo)")
    }
}
