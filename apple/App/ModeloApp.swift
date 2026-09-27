import Foundation
import LufyCore
import SwiftUI

@MainActor
@Observable
final class ModeloApp {
    private(set) var contenido: ContenidoLufy?
    private(set) var meta: ResultadoMeta
    private(set) var origen: OrigenCarga?
    private(set) var actualizando = false
    private(set) var fallo: String?
    private let cargador: CargadorContenido

    init() {
        let contenidoDatos = try? ContenidoEmpaquetado.datosContenido()
        let metaDatos = try? ContenidoEmpaquetado.datosMeta()
        if let contenidoDatos, let decodificado = try? DecodificadorContenido.decodificar(contenidoDatos) {
            contenido = decodificado
            origen = .empaquetado
        } else {
            contenido = nil
            fallo = "No se pudo abrir el contenido incluido en la app."
        }
        if let metaDatos, let valor = try? MetaRecaudacion.decodificar(metaDatos) {
            meta = .valor(valor, .empaquetado)
        } else {
            meta = .fallo("No se pudo leer la cifra de la meta.")
        }

        let almacen: any AlmacenLocal
        if let carpeta = Self.carpetaSoporte() {
            almacen = AlmacenEnDisco(carpeta: carpeta)
        } else {
            almacen = AlmacenEnMemoria()
        }
        cargador = CargadorContenido(
            red: RedURLSession(),
            almacen: almacen,
            empaquetadoContenido: contenidoDatos ?? Data(),
            empaquetadoMeta: metaDatos ?? Data(),
            urlContenido: OrigenPublico.url(OrigenPublico.rutaContenido) ?? OrigenPublico.sitio,
            urlMeta: OrigenPublico.url(OrigenPublico.rutaMeta) ?? OrigenPublico.sitio
        )
    }

    var lineaOrigen: String {
        switch origen {
        case .red:
            return "Actualizado desde Lufy."
        case .cache:
            return "Estás leyendo la copia guardada en el dispositivo."
        case .empaquetado:
            return "Estás leyendo la copia incluida en la app."
        case nil:
            return fallo ?? ""
        }
    }

    func actualizar() async {
        guard !actualizando else { return }
        actualizando = true
        defer { actualizando = false }
        let carga = await cargador.cargar()
        switch carga.contenido {
        case .listo(let nuevo, let origenNuevo):
            contenido = nuevo
            origen = origenNuevo
            fallo = nil
        case .imposible(let mensaje):
            if contenido == nil {
                fallo = mensaje
            }
        }
        meta = carga.meta
    }

    private static func carpetaSoporte() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let carpeta = base.appendingPathComponent("Lufy", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
            return carpeta
        } catch {
            return nil
        }
    }
}
