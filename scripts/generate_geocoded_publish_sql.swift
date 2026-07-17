import Foundation
import MapKit
import SQLite3

struct SourcePlace {
    let id: String
    let query: String
}

@main
struct GeocodedPublishSQLGenerator {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let databaseURL = root.appending(path: "app/Snoots!/maps_database.sqlite")
        let places = try loadPlaces(from: databaseURL)

        print("-- Review before applying. Generated from Apple Maps geocoding.")
        print("begin;")

        var resolvedCount = 0
        for place in places {
            do {
                guard let request = MKGeocodingRequest(addressString: place.query),
                      let item = try await request.mapItems.first else {
                    report("No result for \(place.id): \(place.query)")
                    continue
                }

                let coordinate = item.location.coordinate
                print(
                    "update public.places set latitude = \(coordinate.latitude), "
                        + "longitude = \(coordinate.longitude), "
                        + "verified_at = '2026-07-16T18:24:00+08:00', "
                        + "published = true where id = '\(place.id)';"
                )
                resolvedCount += 1
            } catch {
                report("Failed \(place.id): \(error.localizedDescription)")
            }

            try? await Task.sleep(for: .milliseconds(400))
        }

        print("commit;")
        report("Resolved \(resolvedCount) of \(places.count) places.")
    }

    private static func loadPlaces(from databaseURL: URL) throws -> [SourcePlace] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw GeneratorError.couldNotOpenDatabase
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT category, source_id, name, area, address
        FROM (
            SELECT 'restaurant' AS category, id AS source_id, name, district AS area, address
            FROM restaurants
            UNION ALL
            SELECT 'park', id, name, city, NULL
            FROM pet_parks
            UNION ALL
            SELECT 'hospital', id, name, district, district
            FROM animal_hospitals
        )
        ORDER BY category, source_id
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw GeneratorError.couldNotReadDatabase
        }
        defer { sqlite3_finalize(statement) }

        var places: [SourcePlace] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let category = string(statement, column: 0),
                  let sourceID = string(statement, column: 1),
                  let name = string(statement, column: 2) else { continue }

            let area = string(statement, column: 3)
            let address = string(statement, column: 4)
            let query = [name, address, area, "Taiwan"]
                .compactMap { $0 }
                .joined(separator: ", ")
                .replacingOccurrences(of: "｜", with: ", ")

            places.append(SourcePlace(id: "\(category)-\(sourceID)", query: query))
        }
        return places
    }

    private static func string(_ statement: OpaquePointer?, column: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: value)
    }

    private static func report(_ message: String) {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
    }

    enum GeneratorError: Error {
        case couldNotOpenDatabase
        case couldNotReadDatabase
    }
}
