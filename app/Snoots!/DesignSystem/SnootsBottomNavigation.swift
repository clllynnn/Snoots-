import SwiftUI

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
        case .match: "heart.fill"
        case .maps: "map.fill"
        case .feed: "bubble.left.and.bubble.right.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

struct SnootsBottomNavigation: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                SnootsBottomNavigationItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    select: { select(tab) }
                )

                if tab != AppTab.allCases.last {
                    Spacer(minLength: SnootsBottomNavigationTokens.minimumItemSpacing)
                }
            }
        }
        .padding(.horizontal, SnootsBottomNavigationTokens.horizontalInset)
        .padding(.vertical, SnootsBottomNavigationTokens.verticalInset)
        .background(SnootsPalette.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SnootsPalette.divider)
                .frame(height: 1)
        }
    }

    private func select(_ tab: AppTab) {
        guard selectedTab != tab else { return }
        withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
            selectedTab = tab
        }
    }
}

private struct SnootsBottomNavigationItem: View {
    let tab: AppTab
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Group {
                if isSelected {
                    HStack(spacing: SnootsBottomNavigationTokens.iconLabelSpacing) {
                        icon
                        Text(tab.title)
                            .font(.snootsUI(12, weight: .bold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, SnootsBottomNavigationTokens.activeHorizontalPadding)
                    .frame(height: SnootsBottomNavigationTokens.activeHeight)
                    .background(SnootsPalette.primary, in: Capsule())
                } else {
                    VStack(spacing: 2) {
                        icon
                        Text(tab.title)
                            .font(.snootsUI(11))
                            .lineLimit(1)
                    }
                    .frame(minHeight: SnootsBottomNavigationTokens.activeHeight)
                }
            }
            .foregroundStyle(isSelected ? SnootsPalette.ink : SnootsPalette.inactive)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minWidth: SnootsBottomNavigationTokens.minimumTouchTarget, minHeight: SnootsBottomNavigationTokens.minimumTouchTarget)
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint("Switches to the \(tab.title) tab")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var icon: some View {
        Image(systemName: tab.symbol)
            .font(.system(size: SnootsBottomNavigationTokens.iconSize, weight: .semibold))
            .frame(width: SnootsBottomNavigationTokens.iconSize + 2, height: SnootsBottomNavigationTokens.iconSize + 2)
    }
}

private enum SnootsBottomNavigationTokens {
    static let activeHeight: CGFloat = 40
    static let activeHorizontalPadding: CGFloat = 16
    static let horizontalInset: CGFloat = 18
    static let verticalInset: CGFloat = 6
    static let iconLabelSpacing: CGFloat = 7
    static let iconSize: CGFloat = 16
    static let minimumItemSpacing: CGFloat = 4
    static let minimumTouchTarget: CGFloat = 44
}
