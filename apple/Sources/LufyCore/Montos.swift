import Foundation

public enum Montos {
    /// `$244.802,52` y `244.802,52`: punto de miles y coma decimal, como en los hilos.
    public static func ecuador(_ texto: String) -> Decimal? {
        var limpio = texto.trimmingCharacters(in: .whitespaces)
        if limpio.hasPrefix("$") {
            limpio.removeFirst()
        }
        limpio = limpio.replacingOccurrences(of: " ", with: "")
        guard !limpio.isEmpty else { return nil }
        guard limpio.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789.,-").contains($0) }) else {
            return nil
        }
        let sinMiles = limpio.replacingOccurrences(of: ".", with: "")
        let normalizado = sinMiles.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalizado)
    }
}

public enum EscalaBarras {
    public static func maximo(_ numeros: [Double]) -> Double {
        max(0, numeros.max() ?? 0)
    }

    public static func fraccion(_ numero: Double, maximo: Double) -> Double {
        guard maximo > 0, numero > 0 else { return 0 }
        return min(1, numero / maximo)
    }
}
