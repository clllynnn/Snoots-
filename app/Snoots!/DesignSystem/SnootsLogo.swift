import SwiftUI

struct SnootsLogo: View {
    var size: CGFloat = 52

    var body: some View {
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Snoots")
    }
}
