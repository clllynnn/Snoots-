import Foundation

struct SupabaseNearbyConfiguration: Sendable {
    let projectURL: URL
    let publishableKey: String

    static func load(from bundle: Bundle = .main) -> Self? {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SnootsSupabaseURL") as? String,
              let rawKey = bundle.object(forInfoDictionaryKey: "SnootsSupabasePublishableKey") as? String else {
            return nil
        }

        let urlValue = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyValue = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlValue.isEmpty,
              !keyValue.isEmpty,
              !urlValue.contains("$("),
              !keyValue.contains("$("),
              let projectURL = URL(string: urlValue),
              projectURL.scheme == "https" else {
            return nil
        }

        return Self(projectURL: projectURL, publishableKey: keyValue)
    }
}
struct RemoteNearbySnapshot: Sendable {
    let places: [RemoteNearbyPlace]
    let filterOptions: [RemoteFilterOption]
}

struct RemoteNearbyPlace: Decodable, Sendable {
    let id: String
    let category: String
    let name: String
    let area: String?
    let address: String?
    let latitude: Double
    let longitude: Double
    let appleMapsURL: String?
    let websiteURL: String?
    let sourceURL: String?
    let policySummary: String?
    let dogAccessLabel: String?
    let verificationLevel: String
    let verifiedAt: String?
    let openingHours: [String: String]?
    let filterIDs: [String]
    let distanceMeters: Double

    private enum CodingKeys: String, CodingKey {
        case id, category, name, area, address, latitude, longitude
        case appleMapsURL = "apple_maps_url"
        case websiteURL = "website_url"
        case sourceURL = "source_url"
        case policySummary = "policy_summary"
        case dogAccessLabel = "dog_access_label"
        case verificationLevel = "verification_level"
        case verifiedAt = "verified_at"
        case openingHours = "opening_hours"
        case filterIDs = "filter_ids"
        case distanceMeters = "distance_meters"
    }
}

struct RemoteFilterOption: Decodable, Identifiable, Sendable {
    let id: String
    let category: String
    let titleTraditionalChinese: String
    let titleEnglish: String
    let displayOrder: Int

    private enum CodingKeys: String, CodingKey {
        case id, category
        case titleTraditionalChinese = "title_zh_hant"
        case titleEnglish = "title_en"
        case displayOrder = "display_order"
    }
}

struct SupabaseNearbyClient: Sendable {
    enum ClientError: LocalizedError {
        case invalidEndpoint
        case unexpectedResponse
        case requestFailed(Int)

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint: "The nearby data endpoint is invalid."
            case .unexpectedResponse: "The nearby data service returned an invalid response."
            case let .requestFailed(statusCode): "The nearby data request failed (HTTP \(statusCode))."
            }
        }
    }

    let configuration: SupabaseNearbyConfiguration

    func fetchSnapshot(
        latitude: Double,
        longitude: Double,
        category: String? = nil,
        filterIDs: [String] = []
    ) async throws -> RemoteNearbySnapshot {
        async let places = fetchPlaces(
            latitude: latitude,
            longitude: longitude,
            category: category,
            filterIDs: filterIDs
        )
        async let filterOptions = fetchFilterOptions()
        return try await RemoteNearbySnapshot(places: places, filterOptions: filterOptions)
    }

    private func fetchPlaces(
        latitude: Double,
        longitude: Double,
        category: String?,
        filterIDs: [String]
    ) async throws -> [RemoteNearbyPlace] {
        struct Body: Encodable {
            let latitude: Double
            let longitude: Double
            let category: String?
            let filterIDs: [String]
            let limit = 200

            enum CodingKeys: String, CodingKey {
                case latitude = "p_latitude"
                case longitude = "p_longitude"
                case category = "p_category"
                case filterIDs = "p_filter_ids"
                case limit = "p_limit"
            }
        }

        let body = Body(
            latitude: latitude,
            longitude: longitude,
            category: category,
            filterIDs: filterIDs
        )
        return try await request(
            path: "rest/v1/rpc/nearby_places",
            method: "POST",
            body: JSONEncoder().encode(body)
        )
    }

    private func fetchFilterOptions() async throws -> [RemoteFilterOption] {
        try await request(
            path: "rest/v1/filter_options?select=id,category,title_zh_hant,title_en,display_order&is_active=eq.true&order=category,display_order",
            method: "GET"
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        body: Data? = nil
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: configuration.projectURL)?.absoluteURL else {
            throw ClientError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 20
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ClientError.unexpectedResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ClientError.requestFailed(response.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
