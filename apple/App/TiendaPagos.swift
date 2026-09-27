import Foundation
import Observation
import StoreKit
import LufyCore

enum ProductosLufy {
    static let suscripcionMensual = "com.lufy.app.suscripcion.mensual"
    static let dossierEjemplo = "com.lufy.app.dossier.ejemplo"
    static let suscripciones: Set<String> = [suscripcionMensual]
}

/// StoreKit 2. Con `capaDePagoActiva` en false no consulta productos ni derechos.
@MainActor
@Observable
final class TiendaPagos {
    private(set) var suscrito = false
    private(set) var comprados: Set<String> = []
    private(set) var productos: [Product] = []
    private var escuchando = false

    func preparar(dossiers: [DossierPublico]) async {
        guard Configuracion.capaDePagoActiva else {
            suscrito = false
            comprados = []
            productos = []
            return
        }
        if !escuchando {
            escuchando = true
            Task { await escuchar() }
        }
        await cargar(dossiers: dossiers)
        await refrescarDerechos()
    }

    func comprar(id: String) async -> Bool {
        guard Configuracion.capaDePagoActiva else { return false }
        guard let producto = productos.first(where: { $0.id == id }) else { return false }
        do {
            let resultado = try await producto.purchase()
            switch resultado {
            case .success(let verificacion):
                guard case .verified(let transaccion) = verificacion else { return false }
                await transaccion.finish()
                await refrescarDerechos()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restaurar() async {
        guard Configuracion.capaDePagoActiva else { return }
        try? await AppStore.sync()
        await refrescarDerechos()
    }

    func posee(_ producto: String) -> Bool {
        Configuracion.capaDePagoActiva && (suscrito || comprados.contains(producto))
    }

    func producto(_ id: String) -> Product? {
        productos.first { $0.id == id }
    }

    private func escuchar() async {
        for await resultado in Transaction.updates {
            guard Configuracion.capaDePagoActiva else { continue }
            guard case .verified(let transaccion) = resultado else { continue }
            await transaccion.finish()
            await refrescarDerechos()
        }
    }

    private func cargar(dossiers: [DossierPublico]) async {
        var ids = ProductosLufy.suscripciones
        for dossier in dossiers {
            ids.insert(dossier.producto)
        }
        do {
            productos = try await Product.products(for: ids)
        } catch {
            productos = []
        }
    }

    private func refrescarDerechos() async {
        guard Configuracion.capaDePagoActiva else {
            suscrito = false
            comprados = []
            return
        }
        var ids = Set<String>()
        for await resultado in Transaction.currentEntitlements {
            guard case .verified(let transaccion) = resultado else { continue }
            if transaccion.revocationDate != nil { continue }
            ids.insert(transaccion.productID)
        }
        comprados = ids
        suscrito = !ids.isDisjoint(with: ProductosLufy.suscripciones)
    }
}
