import SwiftUI

enum AppTab: Hashable {
    case garage
    case timeline
    case reminders
    case documents
    case settings
}

enum PaywallReason: String, Identifiable {
    case secondVehicle
    case serviceLimit
    case exportPDF
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .secondVehicle:
            return "Unlock multi-car garage"
        case .serviceLimit:
            return "Keep the full history"
        case .exportPDF:
            return "Export the full passport"
        case .settings:
            return "Upgrade to Pro"
        }
    }

    var message: String {
        switch self {
        case .secondVehicle:
            return "Free includes one vehicle. Pro unlocks an unlimited private garage."
        case .serviceLimit:
            return "Free includes up to 15 service entries total. Pro removes the limit for long-term ownership."
        case .exportPDF:
            return "PDF export is part of Pro so you can generate a polished service passport any time."
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
    @AppStorage("showOnlyCurrentVehicle") var showOnlyCurrentVehicle: Bool = false
    @AppStorage("globalSelectedVehicleID") var globalSelectedVehicleIDString: String = ""
    
    var selectedVehicleID: UUID? {
        get { UUID(uuidString: globalSelectedVehicleIDString) }
        set { globalSelectedVehicleIDString = newValue?.uuidString ?? "" }
    }
}
