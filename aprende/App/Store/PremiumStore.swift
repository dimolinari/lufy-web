import Foundation
import StoreKit
import AprendeCore

/// Costura de StoreKit 2. En la versión 1 no hay productos: `refresh` no llama a la tienda
/// y ningún curso publicado está detrás de un pago.
@MainActor
@Observable
final class PremiumStore {
    private(set) var entitlements = Entitlements.freeOnly
    private(set) var products: [Product] = []
    private(set) var statusMessage: String?
    private let productIDs: [String]
    let subscriptionsEnabled: Bool
    private var updates: Task<Void, Never>?

    init(productIDs: [String], subscriptionsEnabled: Bool = false) {
        self.productIDs = productIDs
        self.subscriptionsEnabled = subscriptionsEnabled
    }

    var isConfigured: Bool { !productIDs.isEmpty }

    func refresh() async {
        guard isConfigured else {
            entitlements = .freeOnly
            products = []
            statusMessage = nil
            return
        }
        do {
            products = try await Product.products(for: productIDs)
            var ownsPremium = false
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result, productIDs.contains(transaction.productID) {
                    ownsPremium = true
                }
            }
            entitlements = Entitlements(premium: ownsPremium)
            statusMessage = nil
            listenForUpdates()
        } catch {
            statusMessage = "No se pudo consultar la tienda."
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refresh()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            statusMessage = "La compra no se completó."
        }
    }

    private func listenForUpdates() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.refresh()
                }
            }
        }
    }
}
