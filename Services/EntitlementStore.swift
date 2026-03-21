import Foundation
import StoreKit

@MainActor
final class EntitlementStore: ObservableObject {
    private enum Limits {
        static let freeVehicles = 1
        static let freeSavedDocuments = 10
    }

    enum PremiumPreviewModule: String, CaseIterable, Codable {
        case finance
        case fuel
        case service
        case resale
    }

    struct PremiumPreviewState: Codable {
        let module: PremiumPreviewModule
        var hasUsedPreview: Bool
        var unlockedByMilestone: Bool
        var lastMilestoneValueShown: Int?
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
    @Published private(set) var premiumPreviewStates: [PremiumPreviewModule: PremiumPreviewState]
    @Published var purchaseErrorMessage: String?

    #if DEBUG
    @Published var debugProOverride = UserDefaults.standard.bool(forKey: Keys.debugProOverride)
    #endif

    private var updatesTask: Task<Void, Never>?

    enum ExportFeature: String {
        case servicePassportPDF
        case csv
        case resaleReport
    }

    private enum Cache {
        static let proAccessGracePeriod: TimeInterval = 60 * 60 * 24 * 3
    }

    private enum Keys {
        static let cachedProUnlocked = "entitlement.cachedProUnlocked"
        static let cachedProUnlockedAt = "entitlement.cachedProUnlockedAt"
        static let debugProOverride = "entitlement.debugProOverride"
        static let premiumPreviewStates = "entitlement.premiumPreviewStates"
    }

    init() {
        isProUnlocked = Self.cachedProAccessIsFresh()
        premiumPreviewStates = Self.loadPremiumPreviewStates()
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
        canExport(.servicePassportPDF)
    }

    func canExportAdvancedReports() -> Bool {
        canExport(.resaleReport)
    }

    func canExport(_ feature: ExportFeature) -> Bool {
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

    func canUseVINLookup() -> Bool {
        hasProAccess
    }

    func previewState(for module: PremiumPreviewModule) -> PremiumPreviewState {
        premiumPreviewStates[module] ?? Self.defaultPreviewState(for: module)
    }

    func hasUsedPreview(for module: PremiumPreviewModule) -> Bool {
        previewState(for: module).hasUsedPreview
    }

    func isPreviewUnlocked(for module: PremiumPreviewModule) -> Bool {
        hasProAccess || previewState(for: module).unlockedByMilestone
    }

    func canShowPreview(for module: PremiumPreviewModule) -> Bool {
        guard !hasProAccess else { return true }
        let state = previewState(for: module)
        return state.unlockedByMilestone && !state.hasUsedPreview
    }

    func unlockPreviewMilestone(for module: PremiumPreviewModule, milestoneValue: Int? = nil) {
        var state = previewState(for: module)
        state.unlockedByMilestone = true
        if let milestoneValue {
            state.lastMilestoneValueShown = milestoneValue
        }
        updatePreviewState(state)
    }

    func lockPreviewMilestone(for module: PremiumPreviewModule) {
        guard !hasProAccess else { return }
        var state = previewState(for: module)
        state.unlockedByMilestone = false
        updatePreviewState(state)
    }

    @discardableResult
    func consumePreview(for module: PremiumPreviewModule) -> Bool {
        guard !hasProAccess else { return true }
        guard canShowPreview(for: module) else { return false }

        var state = previewState(for: module)
        state.hasUsedPreview = true
        updatePreviewState(state)
        return true
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
        persistCachedProAccess(unlocked)
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    private func updatePreviewState(_ state: PremiumPreviewState) {
        premiumPreviewStates[state.module] = state
        persistPreviewStates()
    }

    private func persistPreviewStates() {
        let states = PremiumPreviewModule.allCases.map { previewState(for: $0) }
        guard let encoded = try? JSONEncoder().encode(states) else { return }
        UserDefaults.standard.set(encoded, forKey: Keys.premiumPreviewStates)
    }

    private static func loadPremiumPreviewStates() -> [PremiumPreviewModule: PremiumPreviewState] {
        guard
            let data = UserDefaults.standard.data(forKey: Keys.premiumPreviewStates),
            let decoded = try? JSONDecoder().decode([PremiumPreviewState].self, from: data)
        else {
            return Dictionary(uniqueKeysWithValues: PremiumPreviewModule.allCases.map { ($0, defaultPreviewState(for: $0)) })
        }

        var states = Dictionary(uniqueKeysWithValues: decoded.map { ($0.module, $0) })
        for module in PremiumPreviewModule.allCases where states[module] == nil {
            states[module] = defaultPreviewState(for: module)
        }
        return states
    }

    private static func defaultPreviewState(for module: PremiumPreviewModule) -> PremiumPreviewState {
        PremiumPreviewState(
            module: module,
            hasUsedPreview: false,
            unlockedByMilestone: false,
            lastMilestoneValueShown: nil
        )
    }

    private func persistCachedProAccess(_ unlocked: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(unlocked, forKey: Keys.cachedProUnlocked)

        if unlocked {
            defaults.set(Date(), forKey: Keys.cachedProUnlockedAt)
        } else {
            defaults.removeObject(forKey: Keys.cachedProUnlockedAt)
        }
    }

    private static func cachedProAccessIsFresh(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.bool(forKey: Keys.cachedProUnlocked) else { return false }
        guard let cachedAt = defaults.object(forKey: Keys.cachedProUnlockedAt) as? Date else { return false }
        return now.timeIntervalSince(cachedAt) <= Cache.proAccessGracePeriod
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
