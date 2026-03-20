import SwiftUI

enum AppTab: Hashable {
    case garage
    case timeline
    case reminders
    case settings
}

enum PaywallReason: String, Identifiable {
    case secondVehicle
    case lockedVehicle
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
            return PaywallCopy(
                title: "Compare your garage side by side",
                message: "Unlock multi-vehicle comparisons, garage-wide spend insights, and ownership patterns across vehicles."
            )
        case .lockedVehicle:
            return PaywallCopy(
                title: "Restore access to all your vehicles",
                message: "Pro unlocks your saved vehicles, their history, documents, reminders, and comparison tools."
            )
        case .financeBreakdown:
            return PaywallCopy(
                title: "Find where your money really goes",
                message: "Unlock category breakdowns, ownership cost patterns, and longer-term spend trends."
            )
        case .servicePrediction:
            return PaywallCopy(
                title: "See what may need attention next",
                message: "Unlock smarter maintenance insights, likely service needs, and deeper service health tracking."
            )
        case .fuelTrend:
            return PaywallCopy(
                title: "See your real fuel efficiency",
                message: "Unlock long-term averages, trend charts, period filters, and OCR receipt tools."
            )
        case .resaleReport:
            return PaywallCopy(
                title: "Improve buyer readiness",
                message: "Unlock deeper resale confidence signals, missing proof insights, and stronger ownership records."
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
                title: "Find where your money really goes",
                message: "Unlock category breakdowns, ownership cost patterns, and longer-term spend trends."
            )
        case .fuelTracking:
            return PaywallCopy(
                title: "See your real fuel efficiency",
                message: "Unlock long-term averages, trend charts, period filters, and OCR receipt tools."
            )
        case .ocrScan:
            return PaywallCopy(
                title: "Turn receipts into records instantly",
                message: "Pro extracts the date, amount, mileage, vendor, and notes from a receipt photo and turns it into a structured service record — no manual entry needed."
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
                title: "Unlock the full ownership experience",
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

