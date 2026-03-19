import Foundation
import StoreKit

@MainActor
final class EntitlementStore: ObservableObject {
    private enum Limits {
        static let freeVehicles = 1
        static let freeSavedDocuments = 10
    }

    enum ProPlan: String, CaseIterable {
        case monthly
        case yearly
        case lifetime

        var productID: String {
            switch self {
            case .monthly:
                return "com.robertengel.carservicepassport.pro.monthly"
            case .yearly:
                return "com.robertengel.carservicepassport.pro.yearly"
            case .lifetime:
                return "com.robertengel.carservicepassport.pro.lifetime"
            }
        }
    }

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var isProUnlocked: Bool
    @Published private(set) var isBusy = false
    @Published var purchaseErrorMessage: String?

    #if DEBUG
    @Published var debugProOverride = UserDefaults.standard.bool(forKey: Keys.debugProOverride)
    #endif

    private var updatesTask: Task<Void, Never>?
    private let cachedProAccess: Bool

    private enum Keys {
        static let cachedProUnlocked = "entitlement.cachedProUnlocked"
        static let debugProOverride = "entitlement.debugProOverride"
    }

    init() {
        let cached = UserDefaults.standard.bool(forKey: Keys.cachedProUnlocked)
        cachedProAccess = cached
        isProUnlocked = cached
    }

    deinit {
        updatesTask?.cancel()
    }

    var hasProAccess: Bool {
        #if DEBUG
        return cachedProAccess || isProUnlocked || debugProOverride
        #else
        return cachedProAccess || isProUnlocked
        #endif
    }

    var lifetimeProduct: Product? {
        product(for: .lifetime)
    }

    func prepare() async {
        await loadProducts()
        await refreshEntitlements()
        observeTransactionsIfNeeded()
    }

    var maxVehicles: Int? {
        hasProAccess ? nil : Limits.freeVehicles
    }

    var maxSavedDocuments: Int? {
        hasProAccess ? nil : Limits.freeSavedDocuments
    }

    func canAddVehicle(existingCount: Int) -> Bool {
        hasProAccess || existingCount < Limits.freeVehicles
    }

    func canAddMoreVehicles(existingCount: Int) -> Bool {
        canAddVehicle(existingCount: existingCount)
    }

    func canExportPDF() -> Bool {
        hasProAccess
    }

    func canExportAdvancedReports() -> Bool {
        hasProAccess
    }
    
    func canUseAdvancedReminders() -> Bool {
        hasProAccess
    }

    func canUseMileageReminders() -> Bool {
        hasProAccess
    }
    
    func canUseDocumentVault() -> Bool {
        true
    }

    func canAddSavedDocuments(existingCount: Int, addingCount: Int = 1) -> Bool {
        hasProAccess || existingCount + addingCount <= Limits.freeSavedDocuments
    }

    func canUseUnlimitedDocuments() -> Bool {
        hasProAccess
    }

    func canUseDocumentOCR() -> Bool {
        hasProAccess
    }
    
    func canSeeAnalytics() -> Bool {
        true
    }

    func canViewAdvancedInsights() -> Bool {
        hasProAccess
    }

    func canUseFuelTracking() -> Bool {
        true
    }

    func canUseDetailedFuelTracking() -> Bool {
        hasProAccess
    }

    func canUseFuelAnalytics() -> Bool {
        hasProAccess
    }

    func canUseOCR() -> Bool {
        hasProAccess
    }

    func canUseVINLookup() -> Bool {
        hasProAccess
    }

    func canImportData() -> Bool {
        true
    }

    func product(for plan: ProPlan) -> Product? {
        products[plan.productID]
    }

    func loadProducts() async {
        do {
            let productList = try await Product.products(for: ProPlan.allCases.map { $0.productID })
            products = Dictionary(uniqueKeysWithValues: productList.map { ($0.id, $0) })
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func purchaseLifetimePro() async {
        await purchase(plan: .lifetime)
    }

    func purchase(plan: ProPlan) async {
        guard let product = product(for: plan) else {
            await loadProducts()
            guard let product = product(for: plan) else {
                purchaseErrorMessage = "This plan is not available yet."
                return
            }
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
                if ProPlan.allCases.contains(where: { $0.productID == transaction.productID }) {
                    unlocked = true
                }
            } catch {
                continue
            }
        }

        isProUnlocked = unlocked
        if unlocked {
            UserDefaults.standard.set(true, forKey: Keys.cachedProUnlocked)
        }
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
