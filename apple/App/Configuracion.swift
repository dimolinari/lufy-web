import Foundation

/// Interruptor único de los enlaces de aporte y de compra.
/// Las compilaciones locales lo dejan encendido. Antes de un envío a la
/// App Store hay que leer `apple/README.md`: en Estados Unidos las reglas
/// de enlaces de compra externos pueden exigir apagarlo.
enum Configuracion {
    static let mostrarEnlacesKoFi = true
}
