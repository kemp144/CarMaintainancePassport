import Foundation
import StoreKit

@MainActor
final class EntitlementStore: ObservableObject {
    static let lifetimeProductID = "com.robertengel.carservicepassport.pro.lifetime"

    @Published private(set) var product: Product?
    @Published private(set) var isProUnlocked: Bool
    @Published private(set) var isBusy = false
    @Published var purchaseErrorMessage: String?

    #if DEBUG
    @Published var debugProOverride = UserDefaults.standard.bool(forKey: Keys.debugProOverride)
    #endif

    private var updatesTask: Task<Void, Never>?

    private enum Keys {
        static let cachedProUnlocked = "entitlement.cachedProUnlocked"
        static let debugProOverride = "entitlement.debugProOverride"
    }

    init() {
        isProUnlocked = UserDefaults.standard.bool(forKey: Keys.cachedProUnlocked)
    }

    deinit {
        updatesTask?.cancel()
    }

    var hasProAccess: Bool {
        #if DEBUG
        return isProUnlocked || debugProOverride
        #else
        return isProUnlocked
        #endif
    }

    func prepare() async {
        await loadProducts()
        await refreshEntitlements()
        observeTransactionsIfNeeded()
    }

    func canAddVehicle(existingCount: Int) -> Bool {
        hasProAccess || existingCount < 1
    }

    func canAddService(existingCount: Int) -> Bool {
        hasProAccess || existingCount < 15
    }

    func canExportPDF() -> Bool {
        hasProAccess
    }

    func loadProducts() async {
        do {
            product = try await Product.products(for: [Self.lifetimeProductID]).first
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func purchaseLifetimePro() async {
        guard let product else {
            await loadProducts()
            guard let product else { return }
            await purchase(product)
            return
        }

        await purchase(product)
    }

    func restorePurchases() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func setDebugOverride(_ enabled: Bool) {
        #if DEBUG
        debugProOverride = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.debugProOverride)
        #endif
    }

    private func observeTransactionsIfNeeded() {
        guard updatesTask == nil else { return }

        updatesTask = Task {
            for await _ in Transaction.updates {
                await refreshEntitlements()
            }
        }
    }

    private func purchase(_ product: Product) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                await transaction.finish()
                await refreshEntitlements()
                Haptics.success()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try verify(result)
                if transaction.productID == Self.lifetimeProductID {
                    unlocked = true
                }
            } catch {
                continue
            }
        }

        isProUnlocked = unlocked
        UserDefaults.standard.set(unlocked, forKey: Keys.cachedProUnlocked)
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}

extension EntitlementStore {
    enum StoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            "The App Store purchase could not be verified."
        }
    }
}