import Foundation

enum AnalyticsEvent: String {
    case paywall_viewed
    case paywall_source
    case paywall_tab
    case paywall_context
    case paywall_cta_tapped
    case upgrade_from_second_vehicle
    case upgrade_from_fuel_trend
    case upgrade_from_service_prediction
    case upgrade_from_resale_report
    case upgrade_from_export
    case preview_revealed_once
    case preview_tapped
    case locked_card_tapped
}

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    func track(event: AnalyticsEvent, properties: [String: Any] = [:]) {
        // In a real app, this would send data to Mixpanel, Amplitude, etc.
        print("Analytics: [\(event.rawValue)] - Properties: \(properties)")
        
        // Track milestone-based context
        // This could be used to discover which contextual moment converts best
    }
}
