import Foundation

struct VINLookupService {
    static let shared = VINLookupService()

    struct VINResult {
        let make: String
        let model: String
        let year: Int?
    }

    enum VINError: LocalizedError {
        case invalidLength
        case networkError
        case noData

        var errorDescription: String? {
            switch self {
            case .invalidLength: return "VIN must be 17 characters"
            case .networkError: return "Network request failed"
            case .noData: return "No vehicle data found for this VIN"
            }
        }
    }

    func lookup(vin: String) async throws -> VINResult {
        let trimmed = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 17 else { throw VINError.invalidLength }

        guard let url = URL(string: "https://vpic.nhtsa.dot.gov/api/vehicles/decodevin/\(trimmed)?format=json") else {
            throw VINError.networkError
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct ResultItem: Decodable {
            let Variable: String
            let Value: String?
        }
        struct NHTSAResponse: Decodable {
            let Results: [ResultItem]
        }

        let response = try JSONDecoder().decode(NHTSAResponse.self, from: data)

        let make = response.Results.first(where: { $0.Variable == "Make" })?.Value ?? ""
        let model = response.Results.first(where: { $0.Variable == "Model" })?.Value ?? ""
        let yearStr = response.Results.first(where: { $0.Variable == "Model Year" })?.Value
        let year = yearStr.flatMap { Int($0) }

        guard !make.isEmpty, make != "null" else { throw VINError.noData }

        return VINResult(make: make, model: model.isEmpty || model == "null" ? "" : model, year: year)
    }
}
