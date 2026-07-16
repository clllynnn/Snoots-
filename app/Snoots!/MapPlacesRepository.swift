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
    var coordinate: CLLocationCoordinate2D?

    enum Category: String, CaseIterable, Identifiable {
        case restaurant = "pet_friendly_restaurant"
        case park = "pet_friendly_park"
        case hospital = "animal_hospital"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .restaurant: "Restaurants"
            case .park: "Parks"
            case .hospital: "Hospitals"
            }
        }

        var symbol: String {
            switch self {
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

@MainActor
@Observable
final class MapPlacesRepository {
    private(set) var places: [MapPlace] = []
    private(set) var errorMessage: String?
    private(set) var isResolvingLocations = false
    private var hasResolvedLocations = false

    init() {
        loadPlaces()
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
