import Foundation

public enum OrigenCarga: String, Sendable, Equatable {
    case red
    case cache
    case paquete
}

public enum ResolucionContenido {
    /// Prefiere la red, luego la copia guardada y al final la incluida en la app.
    /// Un candidato vacío o que no pasa `acepta` se descarta.
    public static func elegir(
        red: Data?,
        cache: Data?,
        paquete: Data,
        acepta: (Data) -> Bool
    ) -> (datos: Data, origen: OrigenCarga)? {
        if let red, !red.isEmpty, acepta(red) {
            return (red, .red)
        }
        if let cache, !cache.isEmpty, acepta(cache) {
            return (cache, .cache)
        }
        if !paquete.isEmpty, acepta(paquete) {
            return (paquete, .paquete)
        }
        return nil
    }
}

public enum CatalogoDecodificador {
    public static func catalogo(datos: Data) throws -> Catalogo {
        do {
            return try JSONDecoder().decode(Catalogo.self, from: datos)
        } catch let error as ErrorLufy {
            throw error
        } catch {
            throw ErrorLufy.json(String(describing: error))
        }
    }

    public static func meta(datos: Data) throws -> MetaRecaudacion {
        let meta: MetaRecaudacion
        do {
            meta = try JSONDecoder().decode(MetaRecaudacion.self, from: datos)
        } catch let error as ErrorLufy {
            throw error
        } catch {
            throw ErrorLufy.json(String(describing: error))
        }
        try meta.validar()
        return meta
    }
}
