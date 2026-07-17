import Foundation
import MapKit
import Observation
import SQLite3

struct MapPlace: Identifiable {
    let id: String
    let category: Category
    let name: String
    let area: String?
    let location: String?
    let appleMapsURL: URL?
    let sourceURL: URL?
    let ruleLabels: [String]
    let filterIDs: Set<String>
    let policySummary: String?
    let dogAccessLabel: String?
    let verificationLevel: String
    let verifiedAt: String?
    let distanceMeters: Double?
    var coordinate: CLLocationCoordinate2D?

    enum Category: String, CaseIterable, Identifiable {
        case meetup = "dog_meetup"
        case restaurant = "pet_friendly_restaurant"
        case park = "pet_friendly_park"
        case hospital = "animal_hospital"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .meetup: "Dog meetups"
            case .restaurant: "Restaurants"
            case .park: "Parks"
            case .hospital: "Hospitals"
            }
        }

        var symbol: String {
            switch self {
            case .meetup: "person.2.fill"
            case .restaurant: "fork.knife"
            case .park: "tree.fill"
            case .hospital: "cross.case.fill"
            }
        }
    }

    var subtitle: String {
        [area, location].compactMap { $0 }.joined(separator: " · ")
    }

    var geocodingQuery: String {
        [name, location, area, "Taiwan"].compactMap { $0 }.joined(separator: ", ")
    }
}

struct MapFilterOption: Identifiable, Sendable {
    let id: String
    let category: MapPlace.Category
    let titleTraditionalChinese: String
    let titleEnglish: String
    let displayOrder: Int

    func title(_ language: SnootsLanguage) -> String {
        language.text(titleEnglish, titleTraditionalChinese)
    }
}

@MainActor
@Observable
final class MapPlacesRepository {
    enum DataSource: Equatable {
        case bundledSQLite
        case supabase
    }

    private(set) var places: [MapPlace] = []
    private(set) var filterOptions: [MapFilterOption] = []
    private(set) var dataSource: DataSource = .bundledSQLite
    private(set) var errorMessage: String?
    private(set) var isResolvingLocations = false
    private var hasResolvedLocations = false

    init() {
        loadPlaces()
    }

    func refreshFromRemoteIfConfigured() async {
        await refresh(
            latitude: 25.0330,
            longitude: 121.5480,
            category: nil,
            filterIDs: []
        )
    }

    func refresh(
        latitude: Double,
        longitude: Double,
        category: MapPlace.Category?,
        filterIDs: Set<String>
    ) async {
        guard let configuration = SupabaseNearbyConfiguration.load() else { return }

        do {
            let snapshot = try await SupabaseNearbyClient(configuration: configuration).fetchSnapshot(
                latitude: latitude,
                longitude: longitude,
                category: category?.rawValue,
                filterIDs: filterIDs.sorted()
            )
            let options = snapshot.filterOptions.compactMap { option -> MapFilterOption? in
                guard let category = MapPlace.Category(rawValue: option.category) else { return nil }
                return MapFilterOption(
                    id: option.id,
                    category: category,
                    titleTraditionalChinese: option.titleTraditionalChinese,
                    titleEnglish: option.titleEnglish,
                    displayOrder: option.displayOrder
                )
            }
            let labelsByID = Dictionary(
                uniqueKeysWithValues: options.map { ($0.id, $0.titleTraditionalChinese) }
            )
            let remotePlaces = snapshot.places.compactMap { place -> MapPlace? in
                guard let category = MapPlace.Category(rawValue: place.category) else { return nil }
                return MapPlace(
                    id: place.id,
                    category: category,
                    name: place.name,
                    area: place.area,
                    location: place.address,
                    appleMapsURL: place.appleMapsURL.flatMap(URL.init(string:)),
                    sourceURL: place.sourceURL.flatMap(URL.init(string:)),
                    ruleLabels: place.filterIDs.compactMap { labelsByID[$0] },
                    filterIDs: Set(place.filterIDs),
                    policySummary: place.policySummary,
                    dogAccessLabel: place.dogAccessLabel,
                    verificationLevel: place.verificationLevel,
                    verifiedAt: place.verifiedAt,
                    distanceMeters: place.distanceMeters,
                    coordinate: CLLocationCoordinate2D(
                        latitude: place.latitude,
                        longitude: place.longitude
                    )
                )
            }

            filterOptions = options
            places = remotePlaces
            dataSource = .supabase
            hasResolvedLocations = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveLocationsIfNeeded() async {
        guard !hasResolvedLocations, !isResolvingLocations, !places.isEmpty else { return }
        isResolvingLocations = true
        defer {
            isResolvingLocations = false
            hasResolvedLocations = true
        }

        for index in places.indices where places[index].coordinate == nil {
            if let request = MKGeocodingRequest(addressString: places[index].geocodingQuery),
               let mapItem = try? await request.mapItems.first {
                places[index].coordinate = mapItem.location.coordinate
            }
            try? await Task.sleep(for: .milliseconds(180))
        }
    }

    private func loadPlaces() {
        guard let databaseURL = Bundle.main.url(forResource: "maps_database", withExtension: "sqlite") else {
            errorMessage = "The bundled maps database could not be found."
            return
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            errorMessage = "The maps database could not be opened."
            return
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT category, source_id, name, area, location, apple_maps_url, source_url,
               accepted_dog_size, ground_allowed, leash_required, free_roam
        FROM (
            SELECT 'pet_friendly_restaurant' AS category, id AS source_id, name, district AS area,
                   address AS location, apple_maps_url, source_url,
                   accepted_dog_size, ground_allowed, leash_required, free_roam
            FROM restaurants
            UNION ALL
            SELECT 'pet_friendly_park', id, name, city, NULL, apple_maps_url, source_url,
                   NULL, NULL, leash_required, NULL
            FROM pet_parks
            UNION ALL
            SELECT 'animal_hospital', id, name, district, NULL, apple_maps_url, source_url,
                   NULL, NULL, NULL, NULL
            FROM animal_hospitals
        )
        ORDER BY category, name COLLATE NOCASE
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            errorMessage = "The maps data could not be read."
            return
        }
        defer { sqlite3_finalize(statement) }

        var loadedPlaces: [MapPlace] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let categoryValue = string(from: statement, column: 0),
                  let category = MapPlace.Category(rawValue: categoryValue),
                  let sourceID = string(from: statement, column: 1),
                  let name = string(from: statement, column: 2) else { continue }

            loadedPlaces.append(
                MapPlace(
                    id: "\(category.rawValue)-\(sourceID)",
                    category: category,
                    name: name,
                    area: string(from: statement, column: 3),
                    location: string(from: statement, column: 4),
                    appleMapsURL: string(from: statement, column: 5).flatMap(URL.init(string:)),
                    sourceURL: string(from: statement, column: 6).flatMap(URL.init(string:)),
                    ruleLabels: ruleLabels(
                        acceptedDogSize: string(from: statement, column: 7),
                        groundAllowed: string(from: statement, column: 8),
                        leashRequired: string(from: statement, column: 9),
                        freeRoam: string(from: statement, column: 10)
                    ),
                    filterIDs: [],
                    policySummary: nil,
                    dogAccessLabel: nil,
                    verificationLevel: "needs_reconfirmation",
                    verifiedAt: nil,
                    distanceMeters: nil,
                    coordinate: nil
                )
            )
        }
        places = loadedPlaces
    }

    private func string(from statement: OpaquePointer?, column: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: value)
    }

    private func ruleLabels(
        acceptedDogSize: String?,
        groundAllowed: String?,
        leashRequired: String?,
        freeRoam: String?
    ) -> [String] {
        let labels = [
            acceptedDogSize.map { "體型：\($0)" },
            groundAllowed,
            leashRequired,
            freeRoam
        ]
        var seenLabels = Set<String>()

        return labels.compactMap { label in
            guard let label else { return nil }
            let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLabel.isEmpty, seenLabels.insert(trimmedLabel).inserted else { return nil }
            return trimmedLabel
        }
    }
}
