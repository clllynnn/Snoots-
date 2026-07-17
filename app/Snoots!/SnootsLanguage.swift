import SwiftUI

enum SnootsLanguage: String, CaseIterable, Identifiable {
    case english
    case traditionalChinese

    var id: String { rawValue }
    var label: String { self == .english ? "English" : "繁體中文" }

    var locale: Locale {
        Locale(identifier: self == .traditionalChinese ? "zh-Hant" : "en")
    }

    static var systemDefault: SnootsLanguage {
        Locale.current.language.languageCode?.identifier == "zh" ? .traditionalChinese : .english
    }

    func text(_ english: String, _ traditionalChinese: String) -> String {
        self == .english ? english : traditionalChinese
    }
}

struct VaccineRecord {
    let vaccinatedOn: String
    let validUntil: String
    let clinic: String
    let manufacturer: String
    let batchNumber: String
}

struct PetCareProfile {
    let rabies: VaccineRecord
    let otherVaccinationsCount: Int
    let healthNotes: String
}
