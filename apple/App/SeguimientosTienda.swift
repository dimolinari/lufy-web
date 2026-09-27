import Foundation
import Observation
import UserNotifications
import LufyCore

/// Seguimientos y avisos en un archivo de Application Support.
/// La primera foto del feed no avisa. El permiso local solo se pide si la persona lo activa.
@MainActor
@Observable
final class SeguimientosTienda {
    private(set) var seguimientos: [Seguimiento] = []
    private(set) var avisos: [AvisoSeguimiento] = []
    private(set) var avisosLocales = false

    init() {
        seguimientos = Self.leer([Seguimiento].self, "seguimientos.json") ?? []
        avisos = Self.leer([AvisoSeguimiento].self, "avisos.json") ?? []
    }

    func sigue(_ clase: Seguimiento.Clase, _ clave: String) -> Bool {
        seguimientos.contains { $0.clase == clase && $0.clave == clave }
    }

    func alternar(_ clase: Seguimiento.Clase, _ clave: String) {
        guard Configuracion.capaDePagoActiva else { return }
        let limpia = clave.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return }
        if let indice = seguimientos.firstIndex(where: { $0.clase == clase && $0.clave == limpia }) {
            seguimientos.remove(at: indice)
        } else {
            seguimientos.append(Seguimiento(clase: clase, clave: limpia))
        }
        Self.guardar(seguimientos, "seguimientos.json")
    }

    func registrar(piezas: [PiezaFeed], puedeAvisar: Bool) {
        guard !piezas.isEmpty else { return }
        let ids = Set(piezas.map(\.id))
        let previos = Self.leerIds()
        Self.guardarIds(ids)
        guard puedeAvisar, Configuracion.capaDePagoActiva, let previos else { return }
        let nuevos = AvisosSeguimiento.novedades(
            anteriores: previos,
            piezas: piezas,
            seguimientos: seguimientos
        )
        guard !nuevos.isEmpty else { return }
        var acumulados = avisos
        for aviso in nuevos where !acumulados.contains(where: { $0.id == aviso.id }) {
            acumulados.append(aviso)
            if avisosLocales {
                AvisosLocales.publicar(aviso)
            }
        }
        avisos = acumulados
        Self.guardar(avisos, "avisos.json")
    }

    func revisarPermiso() async {
        guard Configuracion.capaDePagoActiva else {
            avisosLocales = false
            return
        }
        let ajustes = await UNUserNotificationCenter.current().notificationSettings()
        avisosLocales = ajustes.authorizationStatus == .authorized
    }

    func activarAvisosLocales() async {
        guard Configuracion.capaDePagoActiva else { return }
        avisosLocales = await AvisosLocales.autorizar()
    }

    private static func carpeta() -> URL? {
        do {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let destino = base.appendingPathComponent("Lufy/seguimientos", isDirectory: true)
            try FileManager.default.createDirectory(at: destino, withIntermediateDirectories: true)
            return destino
        } catch {
            return nil
        }
    }

    private static func leer<T: Decodable>(_ tipo: T.Type, _ nombre: String) -> T? {
        guard let url = carpeta()?.appendingPathComponent(nombre),
              let datos = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(tipo, from: datos)
    }

    private static func guardar<T: Encodable>(_ valor: T, _ nombre: String) {
        guard let url = carpeta()?.appendingPathComponent(nombre),
              let datos = try? JSONEncoder().encode(valor) else {
            return
        }
        try? datos.write(to: url, options: .atomic)
    }

    private static func leerIds() -> Set<String>? {
        guard let url = carpeta()?.appendingPathComponent("ids.txt"),
              let texto = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return Set(texto.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
    }

    private static func guardarIds(_ ids: Set<String>) {
        guard let url = carpeta()?.appendingPathComponent("ids.txt") else { return }
        let texto = ids.sorted().joined(separator: "\n")
        try? texto.write(to: url, atomically: true, encoding: .utf8)
    }
}

private enum AvisosLocales {
    static func autorizar() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func publicar(_ aviso: AvisoSeguimiento) {
        let contenido = UNMutableNotificationContent()
        contenido.title = "Lufy"
        contenido.body = aviso.titulo
        let pedido = UNNotificationRequest(identifier: aviso.id, content: contenido, trigger: nil)
        UNUserNotificationCenter.current().add(pedido)
    }
}
