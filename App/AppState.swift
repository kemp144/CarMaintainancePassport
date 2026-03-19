import SwiftUI

enum AppTab: Hashable {
    case garage
    case timeline
    case reminders
    case settings
}

enum PaywallReason: String, Identifiable {
    case secondVehicle
    case financeBreakdown
    case servicePrediction
    case fuelTrend
    case resaleReport
    case exportPDF
    case advancedReminders
    case documentVault
    case analytics
    case fuelTracking
    case ocrScan
    case vinLookup
    case importData
    case settings

    var id: String { rawValue }
}

struct PaywallPresentationContext {
    var totalOwnershipSpend: Double? = nil
    var currencyCode: String? = nil
    var buyerReadyScore: Int? = nil
    var validFuelCycleCount: Int? = nil
    var maintenanceHistoryCount: Int? = nil
    var vehicleCount: Int? = nil
}

struct PaywallCopy {
    let title: String
    let message: String
}

enum PaywallCopyBuilder {
    static func build(for reason: PaywallReason, context: PaywallPresentationContext?) -> PaywallCopy {
        switch reason {
        case .secondVehicle:
            let vehicleMessage: String
            if let vehicleCount = context?.vehicleCount, vehicleCount >= 1 {
                vehicleMessage = "A second vehicle unlocks the real value of garage comparison."
            } else {
                vehicleMessage = "Free stays useful for one car. Pro lets you compare vehicles, track the full garage, and keep every history together."
            }
            return PaywallCopy(
                title: "Keep every car in one place",
                message: vehicleMessage
            )
        case .financeBreakdown:
            let spendText = context.flatMap { ctx -> String? in
                guard let total = ctx.totalOwnershipSpend else { return nil }
                return AppFormatters.currency(total, code: ctx.currencyCode ?? "EUR")
            } ?? "your ownership costs"
            return PaywallCopy(
                title: "See what drives ownership costs",
                message: "You've logged \(spendText) in ownership costs. Pro shows which categories drive it."
            )
        case .servicePrediction:
            let message: String
            if let maintenanceHistoryCount = context?.maintenanceHistoryCount, maintenanceHistoryCount >= 3 {
                message = "Your maintenance history is ready for smarter predictions."
            } else {
                message = "Pro highlights what may need attention next as your maintenance history grows."
            }
            return PaywallCopy(
                title: "Stay ahead of maintenance",
                message: message
            )
        case .fuelTrend:
            let message: String
            if let validFuelCycleCount = context?.validFuelCycleCount, validFuelCycleCount >= 3 {
                message = "You now have enough valid fuel history to unlock long-term trends."
            } else {
                message = "Pro keeps long-term fuel trends, cleaner averages, and deeper consumption context ready as your history grows."
            }
            return PaywallCopy(
                title: "See your real fuel efficiency",
                message: message
            )
        case .resaleReport:
            let message: String
            if let buyerReadyScore = context?.buyerReadyScore {
                message = "Your vehicle is \(buyerReadyScore)% buyer-ready. Pro shows what still lowers confidence."
            } else {
                message = "Pro shows what still lowers buyer confidence and helps you shape a cleaner resale story."
            }
            return PaywallCopy(
                title: "Turn records into buyer confidence",
                message: message
            )
        case .exportPDF:
            return PaywallCopy(
                title: "Create a buyer-ready history",
                message: "Export a polished service passport, a buyer-ready resale report, and clean records whenever you need to share the full story."
            )
        case .advancedReminders:
            return PaywallCopy(
                title: "Stay ahead of maintenance",
                message: "Add mileage-based reminders and due-soon guidance so maintenance follows how much you actually drive."
            )
        case .documentVault:
            return PaywallCopy(
                title: "Keep your paperwork organized",
                message: "Keep more documents in one place, capture receipts faster with OCR, and build a cleaner ownership record."
            )
        case .analytics:
            return PaywallCopy(
                title: "See your real cost of ownership",
                message: "Start with the essentials for free, then unlock deeper cost breakdowns, fuel trends, maintenance insights, and resale tools."
            )
        case .fuelTracking:
            return PaywallCopy(
                title: "See your real fuel efficiency",
                message: "Log fuel for free, then unlock long-term averages, trend charts, efficiency insights, and cleaner receipt capture with Pro."
            )
        case .ocrScan:
            return PaywallCopy(
                title: "Scan receipts automatically",
                message: "Let the app extract receipt details so service entries take less time."
            )
        case .vinLookup:
            return PaywallCopy(
                title: "Auto-fill vehicle details",
                message: "Fill vehicle details faster from a VIN lookup."
            )
        case .importData:
            return PaywallCopy(
                title: "Import your existing data",
                message: "Bring your existing records into Car Service Passport in one step."
            )
        case .settings:
            return PaywallCopy(
                title: "Upgrade to Pro",
                message: "Unlock full cost breakdowns, fuel efficiency tracking, smarter maintenance insights, resale tools, polished exports, and an unlimited garage."
            )
        }
    }
}

@MainActor
final class PaywallCoordinator: ObservableObject {
    @Published var reason: PaywallReason?
    @Published var context: PaywallPresentationContext?

    func present(_ reason: PaywallReason, context: PaywallPresentationContext? = nil) {
        self.reason = reason
        self.context = context
    }

    func dismiss() {
        reason = nil
        context = nil
    }
}
@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .garage
    @Published var dataRefreshToken = UUID()
    
    @AppStorage("showOnlyCurrentVehicle") var showOnlyCurrentVehicle: Bool = false
    @AppStorage("globalSelectedVehicleID") var globalSelectedVehicleIDString: String = ""
    @Published var timelineCategory: String = "All" // "All", "Maintenance", "Repairs", "Documents", "Expenses"
    
    var selectedVehicleID: UUID? {
        get { UUID(uuidString: globalSelectedVehicleIDString) }
        set { globalSelectedVehicleIDString = newValue?.uuidString ?? "" }
    }

    func refreshDataViews() {
        dataRefreshToken = UUID()
    }
}
