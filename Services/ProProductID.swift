import Foundation

enum ProProductID: String, CaseIterable {
    case monthly = "com.carmaintenance.pro.monthly"
    case yearly = "com.carmaintenance.pro.yearly"
    case lifetime = "com.tvojapp.carmaintenance.pro.lifetime"

    static var allProductIDs: [String] {
        allCases.map(\.rawValue)
    }
}
