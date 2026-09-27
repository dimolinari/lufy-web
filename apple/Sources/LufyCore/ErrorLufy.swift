import Foundation

public enum ErrorLufy: Error, Equatable, Sendable, CustomStringConvertible {
    case schema(Int)
    case metaInvalida(String)
    case enlaceProhibido(String)
    case archivoInvalido(String)
    case textoProhibido(String)
    case fechaInvalida(String)
    case contenidoIncompleto(String)
    case json(String)

    public var description: String {
        switch self {
        case .schema(let n):
            return "Esquema no reconocido: \(n)"
        case .metaInvalida(let detalle):
            return "Meta inválida: \(detalle)"
        case .enlaceProhibido(let detalle):
            return "Enlace no permitido: \(detalle)"
        case .archivoInvalido(let detalle):
            return "Copia archivada inválida: \(detalle)"
        case .textoProhibido(let detalle):
            return "Texto no permitido: \(detalle)"
        case .fechaInvalida(let detalle):
            return "Fecha inválida: \(detalle)"
        case .contenidoIncompleto(let detalle):
            return "Contenido incompleto: \(detalle)"
        case .json(let detalle):
            return "JSON inválido: \(detalle)"
        }
    }
}

public enum Fechas {
    public static func isoValida(_ texto: String) -> Bool {
        guard texto.count == 10 else { return false }
        let partes = texto.split(separator: "-", omittingEmptySubsequences: false)
        guard partes.count == 3,
              partes[0].count == 4,
              partes[1].count == 2,
              partes[2].count == 2,
              let anio = Int(partes[0]),
              let mes = Int(partes[1]),
              let dia = Int(partes[2]) else {
            return false
        }
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var componentes = DateComponents()
        componentes.calendar = calendario
        componentes.timeZone = calendario.timeZone
        componentes.year = anio
        componentes.month = mes
        componentes.day = dia
        guard let fecha = calendario.date(from: componentes) else { return false }
        return calendario.component(.year, from: fecha) == anio
            && calendario.component(.month, from: fecha) == mes
            && calendario.component(.day, from: fecha) == dia
    }
}

public enum Formato {
    /// Igual que `assets/js/meta.js`: coma de miles, punto decimal.
    public static func dolarMeta(_ valor: Double) -> String {
        let negativo = valor < 0
        let centavos = Int((abs(valor) * 100).rounded())
        let signo = negativo ? "-$" : "$"
        let entero = agrupar(String(centavos / 100), separador: ",")
        if centavos % 100 == 0 {
            return signo + entero
        }
        return signo + entero + "." + String(format: "%02d", centavos % 100)
    }

    /// Cifras del hilo: punto de miles y coma decimal, como en la web.
    public static func dolarEs(_ plano: String) -> String? {
        let limpio = plano.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return nil }
        let negativo = limpio.hasPrefix("-")
        let cuerpo = negativo ? String(limpio.dropFirst()) : limpio
        let partes = cuerpo.split(separator: ".", omittingEmptySubsequences: false)
        guard partes.count == 1 || partes.count == 2 else { return nil }
        guard let enteroTexto = partes.first, !enteroTexto.isEmpty, enteroTexto.allSatisfy(\.isNumber) else {
            return nil
        }
        var fraccion = partes.count == 2 ? String(partes[1]) : "00"
        guard fraccion.allSatisfy(\.isNumber) else { return nil }
        if fraccion.isEmpty { fraccion = "00" }
        if fraccion.count == 1 { fraccion += "0" }
        if fraccion.count > 2 {
            guard let redondeado = redondear(entero: String(enteroTexto), fraccion: fraccion) else {
                return nil
            }
            return (negativo ? "-$" : "$") + redondeado.entero + "," + redondeado.fraccion
        }
        let agrupado = agrupar(String(enteroTexto), separador: ".")
        return (negativo ? "-$" : "$") + agrupado + "," + fraccion
    }

    public static func dolarEsEntero(_ valor: Int) -> String {
        let negativo = valor < 0
        return (negativo ? "-$" : "$") + agrupar(String(abs(valor)), separador: ".")
    }

    public static func enteroEs(_ valor: Int) -> String {
        let negativo = valor < 0
        let numero = agrupar(String(abs(valor)), separador: ".")
        return negativo ? "-" + numero : numero
    }

    public static func agrupar(_ digitos: String, separador: Character) -> String {
        let recortado = digitos.drop(while: { $0 == "0" })
        let cuerpo = recortado.isEmpty ? "0" : String(recortado)
        var salida: [Character] = []
        for (indice, caracter) in cuerpo.reversed().enumerated() {
            if indice > 0, indice.isMultiple(of: 3) {
                salida.append(separador)
            }
            salida.append(caracter)
        }
        return String(salida.reversed())
    }

    private static func redondear(entero: String, fraccion: String) -> (entero: String, fraccion: String)? {
        let digitos = Array(fraccion)
        guard digitos.count > 2 else { return nil }
        let subir = digitos[2] >= "5"
        var centavos = Array(digitos.prefix(2))
        var enteros = Array(entero)
        if subir {
            var acarreo = true
            for indice in centavos.indices.reversed() {
                guard acarreo else { break }
                if centavos[indice] == "9" {
                    centavos[indice] = "0"
                } else if let valor = centavos[indice].wholeNumberValue {
                    centavos[indice] = Character(String(valor + 1))
                    acarreo = false
                }
            }
            if acarreo {
                var i = enteros.count - 1
                while acarreo && i >= 0 {
                    if enteros[i] == "9" {
                        enteros[i] = "0"
                    } else if let valor = enteros[i].wholeNumberValue {
                        enteros[i] = Character(String(valor + 1))
                        acarreo = false
                    }
                    i -= 1
                }
                if acarreo { enteros.insert("1", at: 0) }
            }
        }
        return (agrupar(String(enteros), separador: "."), String(centavos))
    }
}
