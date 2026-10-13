import Foundation

/// Beta v1 reference rules. These are product estimates, not veterinary advice.
struct DogActivityRecommendation: Equatable {
    enum Level: String {
        case low = "低"
        case medium = "中"
        case high = "高"
    }

    let level: Level?
    let dailyRange: String?
    let guidance: String
    let sourceURL: URL?

    var title: String { level.map { "\($0.rawValue)活動量" } ?? "活動量待確認" }

    private struct BreedRule {
        let size: String
        let minimumMonths: Int
        let level: Level
        let sourcePath: String
    }

    private static let baseURL = "https://www.pdsa.org.uk/pet-help-and-advice/looking-after-your-pet/puppies-dogs/"
    private static let rules: [String: BreedRule] = [
        "博美": .init(size: "小型犬", minimumMonths: 12, level: .low, sourcePath: "small-dogs/pomeranian"),
        "吉娃娃": .init(size: "小型犬", minimumMonths: 12, level: .low, sourcePath: "small-dogs/chihuahua"),
        "比熊": .init(size: "小型犬", minimumMonths: 12, level: .low, sourcePath: "small-dogs/bichon-frise"),
        "比熊犬": .init(size: "小型犬", minimumMonths: 12, level: .low, sourcePath: "small-dogs/bichon-frise"),
        "約克夏": .init(size: "小型犬", minimumMonths: 12, level: .low, sourcePath: "small-dogs/yorkshire-terrier"),
        "西高地白㹴": .init(size: "小型犬", minimumMonths: 12, level: .medium, sourcePath: "small-dogs/west-highland-white-terrier"),
        "英國可卡犬": .init(size: "中型犬", minimumMonths: 18, level: .medium, sourcePath: "medium-dogs/cocker-spaniel"),
        "邊境牧羊犬": .init(size: "中型犬", minimumMonths: 18, level: .high, sourcePath: "medium-dogs/border-collie"),
        "黃金獵犬": .init(size: "大型犬", minimumMonths: 24, level: .high, sourcePath: "large-dogs/golden-retriever"),
        "西伯利亞哈士奇": .init(size: "大型犬", minimumMonths: 24, level: .high, sourcePath: "large-dogs/siberian-husky")
    ]

    static func calculate(
        breed: String,
        size: String,
        birthDate: Date?,
        breedMappingPending: Bool,
        needs: [String],
        asOf date: Date = .now
    ) -> Self {
        let pending = Self(
            level: nil, dailyRange: nil,
            guidance: "目前資料不足以提供合適的活動量級別。可先採短時間、分次、低衝擊的活動，讓狗狗自主休息；仍可繼續配對。",
            sourceURL: nil
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        guard let birthDate, birthDate <= date,
              let months = calendar.dateComponents([.month], from: birthDate, to: date).month,
              months < 96,
              !breedMappingPending,
              !needs.contains("留意關節"), !needs.contains("避免跳躍"),
              let rule = rules[breed], rule.size == size,
              months >= rule.minimumMonths else { return pending }

        let dailyRange = switch rule.level {
        case .low: "每日 30–60 分鐘（參考區間）"
        case .medium: "每日 60–90 分鐘（參考區間）"
        case .high: "每日 90–120 分鐘以上（依個體調整）"
        }
        let rest = "建議分次、循序增加，依狗狗狀態休息；不用一次完成，也不以區間上限為目標。"
        let tailored = needs.contains("避免集體追逐") || needs.contains("給予獨立空間")
            ? "避免集體追逐，優先選個別嗅聞或舒適散步。"
            : ""
        return Self(
            level: rule.level, dailyRange: dailyRange,
            guidance: rest + tailored,
            sourceURL: URL(string: baseURL + rule.sourcePath)
        )
    }
}
