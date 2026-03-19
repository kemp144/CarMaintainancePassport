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
            return "Unlock an unlimited garage"
        case .exportPDF:
            return "Export a polished passport"
        case .advancedReminders:
            return "Unlock smarter reminders"
        case .documentVault:
            return "Unlock a smarter glovebox"
        case .analytics:
            return "See your ownership costs clearly"
        case .fuelTracking:
            return "Unlock detailed fuel tracking"
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
            return "Free stays useful for one car. Pro lets you keep every vehicle in one organized garage."
        case .exportPDF:
            return "Create a polished, resale-ready PDF passport whenever you need to share the full history."
        case .advancedReminders:
            return "Add mileage-based reminders so maintenance follows how much you actually drive."
        case .documentVault:
            return "Keep more documents in one place, unlock OCR receipt capture, and organize paperwork with a richer glovebox workflow."
        case .analytics:
            return "See where ownership costs go and spot the patterns that matter."
        case .fuelTracking:
            return "Log fuel for free, then unlock consumption, charts, filters, OCR, and deeper fuel insights with Pro."
        case .ocrScan:
            return "Let the app extract receipt details so service entries take less time."
        case .vinLookup:
            return "Fill vehicle details faster from a VIN lookup."
        case .importData:
            return "Bring your existing records into Car Service Passport in one step."
        case .settings:
            return "Unlock unlimited vehicles, fuel insights, OCR, premium exports, and smarter reminder controls."
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
