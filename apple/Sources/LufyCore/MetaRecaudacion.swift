import Foundation

public struct MetaRecaudacion: Sendable, Equatable {
    public var metaUSD: Decimal
    public var recaudadoUSD: Decimal
    public var actualizado: String
    public var texto: String
    public var fraccion: Double
    public var valorAccesible: String

    public static func decodificar(_ datos: Data) throws -> MetaRecaudacion {
        let cruda: Cruda
        do {
            cruda = try JSONDecoder().decode(Cruda.self, from: datos)
        } catch {
            throw ErrorContenido.metaInvalida
        }
        return try interpretar(meta: cruda.goal_usd, recaudado: cruda.raised_usd, actualizado: cruda.updated)
    }

    public static func interpretar(meta: Decimal, recaudado: Decimal, actualizado: String) throws -> MetaRecaudacion {
        guard meta > 0, recaudado >= 0, Fechas.isoValida(actualizado) else {
            throw ErrorContenido.metaInvalida
        }
        let texto = "\(FormatoDinero.dolaresEEUU(recaudado)) de \(FormatoDinero.dolaresEEUU(meta))"
        let tope = min(recaudado, meta)
        let metaD = NSDecimalNumber(decimal: meta).doubleValue
        let topeD = NSDecimalNumber(decimal: tope).doubleValue
        let fraccion = metaD > 0 ? min(1, max(0, topeD / metaD)) : 0
        if recaudado == 0 {
            return MetaRecaudacion(
                metaUSD: meta,
                recaudadoUSD: recaudado,
                actualizado: actualizado,
                texto: texto,
                fraccion: 0,
                valorAccesible: "\(texto). Actualizado: \(actualizado)."
            )
        }
        return MetaRecaudacion(
            metaUSD: meta,
            recaudadoUSD: recaudado,
            actualizado: actualizado,
            texto: texto,
            fraccion: fraccion,
            valorAccesible: "\(texto). Actualizado: \(actualizado)."
        )
    }
}

public enum FormatoDinero {
    /// Dólares de Estados Unidos, coma de miles, como `data/meta.json` en la web.
    public static func dolaresEEUU(_ valor: Decimal) -> String {
        let negativo = valor < 0
        var magnitud = negativo ? -valor : valor
        var redondeado = Decimal()
        NSDecimalRound(&redondeado, &magnitud, 2, .plain)
        var centavos = redondeado * 100
        var centavosEnteros = Decimal()
        NSDecimalRound(&centavosEnteros, &centavos, 0, .plain)
        let cents = NSDecimalNumber(decimal: centavosEnteros).intValue
        let entero = cents / 100
        let frac = abs(cents % 100)
        let esEntero = frac == 0
        let conMiles = agrupar(entero)
        let cuerpo = esEntero ? conMiles : conMiles + String(format: ".%02d", frac)
        return (negativo ? "-$" : "$") + cuerpo
    }

    private static func agrupar(_ entero: Int) -> String {
        let digitos = String(abs(entero))
        var grupos: [String] = []
        var resto = digitos
        while resto.count > 3 {
            let indice = resto.index(resto.endIndex, offsetBy: -3)
            grupos.insert(String(resto[indice...]), at: 0)
            resto = String(resto[..<indice])
        }
        grupos.insert(resto, at: 0)
        return grupos.joined(separator: ",")
    }
}

public enum Fechas {
    public static func isoValida(_ texto: String) -> Bool {
        let partes = texto.split(separator: "-", omittingEmptySubsequences: false)
        guard partes.count == 3,
              partes[0].count == 4,
              partes[1].count == 2,
              partes[2].count == 2,
              let anio = Int(partes[0]),
              let mes = Int(partes[1]),
              let dia = Int(partes[2])
        else { return false }
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var componentes = DateComponents()
        componentes.year = anio
        componentes.month = mes
        componentes.day = dia
        guard let fecha = calendario.date(from: componentes) else { return false }
        let leida = calendario.dateComponents([.year, .month, .day], from: fecha)
        return leida.year == anio && leida.month == mes && leida.day == dia
    }
}

private struct Cruda: Decodable {
    var goal_usd: Decimal
    var raised_usd: Decimal
    var updated: String
}
