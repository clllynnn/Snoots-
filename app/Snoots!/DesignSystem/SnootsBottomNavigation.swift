enum AppTab: CaseIterable, Hashable {
    case match, maps, feed, profile

    var title: String {
        switch self {
        case .match: "Match"
        case .maps: "Maps"
        case .feed: "Feed"
        case .profile: "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .match: "heart"
        case .maps: "map"
        case .feed: "bubble.left.and.bubble.right"
        case .profile: "person.crop.circle"
        }
    }
}
