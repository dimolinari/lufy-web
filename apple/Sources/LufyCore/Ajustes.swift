import Foundation

/// Un solo interruptor para los enlaces de Ko-fi (aporte, membresía, libro y muestra).
///
/// `true` en compilaciones locales. Antes de TestFlight o App Store, léase
/// `apple/README.md`: en Estados Unidos las reglas de enlaces de compra externa
/// cambian, y un enlace a un bien digital puede rechazarse.
public enum Ajustes {
    public static let muestraEnlacesKoFi = true

    public static func enlaceKoFi(_ url: URL, muestra: Bool = muestraEnlacesKoFi) -> URL? {
        guard muestra else { return nil }
        return PoliticaEnlaces.urlKoFi(url)
    }
}
