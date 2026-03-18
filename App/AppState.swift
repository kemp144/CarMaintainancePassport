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
            return "Unlock multi-car garage"
        case .exportPDF:
            return "Export the full passport"
        case .advancedReminders:
            return "Unlock smart maintenance reminders"
        case .documentVault:
            return "Secure your car's documents"
        case .analytics:
            return "Unlock spending analytics"
        case .fuelTracking:
            return "Track your fuel costs"
        case .ocrScan:
            return "Scan receipts automatically"
        case .vinLookup:
            return "Auto-fill vehicle details"
        case .importData:
            return "Import your data"
        case .settings:
            return "Upgrade to Pro"
        }
    }

    var message: String {
        switch self {
        case .secondVehicle:
            return "Free includes one vehicle. Pro unlocks an unlimited private garage."
        case .exportPDF:
            return "Generate a polished, multi-page service passport PDF to increase resale value."
        case .advancedReminders:
            return "Set precise reminders by mileage or combined date & mileage triggers."
        case .documentVault:
            return "Keep all your insurance, registration, and title documents safe in one place."
        case .analytics:
            return "View detailed charts and breakdown of your vehicle's lifetime costs."
        case .fuelTracking:
            return "Log every fill-up, track consumption and total fuel costs over time."
        case .ocrScan:
            return "Point your camera at a receipt and let the app extract the date, cost, mileage and workshop automatically."
        case .vinLookup:
            return "Enter your VIN and instantly fill in make, model and year from the official database."
        case .importData:
            return "Restore a previous backup or move your data from another device."
        case .settings:
            return "A one-time upgrade unlocks the complete service passport experience."
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
    
    @AppStorage("showOnlyCurrentVehicle") var showOnlyCurrentVehicle: Bool = false
    @AppStorage("globalSelectedVehicleID") var globalSelectedVehicleIDString: String = ""
    @Published var timelineCategory: String = "All" // "All", "Maintenance", "Repairs", "Documents", "Expenses"
    
    var selectedVehicleID: UUID? {
        get { UUID(uuidString: globalSelectedVehicleIDString) }
        set { globalSelectedVehicleIDString = newValue?.uuidString ?? "" }
    }
}
