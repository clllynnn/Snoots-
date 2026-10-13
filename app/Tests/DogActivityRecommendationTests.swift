import Foundation

// Compile with DogActivityRecommendation.swift; simulator and network are not needed.
@main
struct DogActivityRecommendationTests {
    static func main() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13))!
        func birthday(_ monthsAgo: Int) -> Date {
            calendar.date(byAdding: .month, value: -monthsAgo, to: today)!
        }
        func result(_ breed: String, _ size: String, _ months: Int, _ needs: [String] = ["無特殊需求"], pending: Bool = false) -> DogActivityRecommendation {
            DogActivityRecommendation.calculate(
                breed: breed, size: size, birthDate: birthday(months),
                breedMappingPending: pending, needs: needs, asOf: today
            )
        }
        precondition(result("博美", "小型犬", 36).level == .low)
        precondition(result("博美", "小型犬", 10).level == nil)
        precondition(result("英國可卡犬", "中型犬", 15).level == nil)
        precondition(result("英國可卡犬", "中型犬", 18).level == .medium)
        precondition(result("黃金獵犬", "大型犬", 20).level == nil)
        precondition(result("黃金獵犬", "大型犬", 24).level == .high)
        precondition(result("博美", "小型犬", 96).level == nil)
        precondition(result("米格魯", "中型犬", 36).level == nil)
        precondition(result("博美", "小型犬", 36, pending: true).level == nil)
        precondition(result("博美", "大型犬", 36).level == nil)
        precondition(result("博美", "小型犬", 36, ["留意關節"]).level == nil)
        precondition(result("博美", "小型犬", 36, ["無特殊需求"]).dailyRange != nil)
        print("Dog activity recommendation: 12 checks passed")
    }
}
