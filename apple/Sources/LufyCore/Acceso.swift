import Foundation

/// La fecha `early_access_until` del feed manda.
/// `diasPorDefecto` es la convención del publicador al calcular esa fecha.
public enum AccesoTemprano {
    public static let diasPorDefecto = 7

    public static func visible(
        hasta: String?,
        ahora: Date,
        capaDePagoActiva: Bool,
        suscrito: Bool
    ) -> Bool {
        guard capaDePagoActiva else { return true }
        if suscrito { return true }
        guard let hasta, !hasta.isEmpty else { return true }
        guard let limite = instante(hasta) else { return false }
        return ahora >= limite
    }

    /// Un dossier no es contenido de base. Con la capa apagada no se ofrece.
    /// Con la capa encendida, quien está suscrito o ya lo compró lo ve;
    /// el resto lo ve cuando llegó la fecha publicada.
    public static func dossierVisible(
        hasta: String?,
        ahora: Date,
        capaDePagoActiva: Bool,
        suscrito: Bool,
        comprado: Bool
    ) -> Bool {
        guard capaDePagoActiva else { return false }
        if suscrito || comprado { return true }
        return visible(hasta: hasta, ahora: ahora, capaDePagoActiva: true, suscrito: false)
    }

    /// Día civil: inicio de ese día en UTC. Marca con hora: el instante exacto.
    public static func instante(_ texto: String) -> Date? {
        if let marca = RitmoFeed.interpretarMarca(texto) {
            return marca
        }
        guard Fechas.isoValida(texto) else { return nil }
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let partes = texto.split(separator: "-")
        var componentes = DateComponents()
        componentes.calendar = calendario
        componentes.timeZone = calendario.timeZone
        componentes.year = Int(partes[0])
        componentes.month = Int(partes[1])
        componentes.day = Int(partes[2])
        return calendario.date(from: componentes)
    }
}
