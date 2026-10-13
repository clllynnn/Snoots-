import SwiftUI

/// Shared artwork for chat entry points; button appearance remains native.
struct SnootsChatIcon: View {
    @ScaledMetric(relativeTo: .body) private var size = 24.0

    var body: some View {
        Image("ChatEntryIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .mask {
                // Remove only the three interior dots; preserve the supplied
                // bubble outline and its tail exactly, at every icon size.
                Path { path in
                    path.addRect(CGRect(x: 0, y: 0, width: size, height: size))
                    path.addRect(CGRect(x: size * 0.25, y: size * 0.32, width: size * 0.5, height: size * 0.24))
                }
                .fill(style: FillStyle(eoFill: true))
            }
            .accessibilityHidden(true)
    }
}
