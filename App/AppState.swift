import SwiftUI

enum AppTab: Hashable {
    case garage
    case timeline
    case reminders
    case settings
}

enum PaywallReason: String, Identifiable {
    case secondVehicle
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

    var title: String {
        switch self {
        case .secondVehicle:
            return "Keep every car in one place"
        case .exportPDF:
            return "Create a buyer-ready history"
        case .advancedReminders:
            return "Stay ahead of maintenance"
        case .documentVault:
            return "Keep your paperwork organized"
        case .analytics:
            return "See your real cost of ownership"
        case .fuelTracking:
            return "See your real fuel efficiency"
        case .ocrScan:
            return "Scan receipts automatically"
        case .vinLookup:
            return "Auto-fill vehicle details"
        case .importData:
            return "Import your existing data"
        case .settings:
            return "Upgrade to Pro"
        }
    }

    var message: String {
        switch self {
        case .secondVehicle:
            return "Free stays useful for one car. Pro lets you compare vehicles, track the full garage, and keep every history together."
        case .exportPDF:
            return "Export a polished service passport, a buyer-ready resale report, and clean records whenever you need to share the full story."
        case .advancedReminders:
            return "Add mileage-based reminders and due-soon guidance so maintenance follows how much you actually drive."
        case .documentVault:
            return "Keep more documents in one place, capture receipts faster with OCR, and build a cleaner ownership record."
        case .analytics:
            return "Start with the essentials for free, then unlock deeper cost breakdowns, fuel trends, maintenance insights, and resale tools."
        case .fuelTracking:
            return "Log fuel for free, then unlock long-term averages, trend charts, efficiency insights, and cleaner receipt capture with Pro."
        case .ocrScan:
            return "Let the app extract receipt details so service entries take less time."
        case .vinLookup:
            return "Fill vehicle details faster from a VIN lookup."
        case .importData:
            return "Bring your existing records into Car Service Passport in one step."
        case .settings:
            return "Unlock full cost breakdowns, fuel efficiency tracking, smarter maintenance insights, resale tools, polished exports, and an unlimited garage."
        }
    }
}

@MainActor
final class PaywallCoordinator: ObservableObject {
    @Published var reason: PaywallReason?

    func present(_ reason: PaywallReason) {
        self.reason = reason
    }

    func dismiss() {
        reason = nil
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
