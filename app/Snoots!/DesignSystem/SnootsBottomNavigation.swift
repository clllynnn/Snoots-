import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

enum AppTab: CaseIterable, Hashable {
    case match, maps, feed, chats, profile

    var title: String {
        switch self {
        case .match: "Match"
        case .maps: "Maps"
        case .feed: "Home"
        case .chats: "Chats"
        case .profile: "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .match: "pawprint"
        case .maps: "map"
        case .feed: "house"
        case .chats: "bubble.left.and.bubble.right"
        case .profile: "person.crop.circle"
        }
    }

    /// Explicit images prevent the native tab bar from filling inactive symbols.
    func icon(isSelected: Bool) -> Image {
        Image(uiImage: Self.icons[self]![isSelected ? 1 : 0])
            .renderingMode(.original)
    }

    private static let icons: [AppTab: [UIImage]] = Dictionary(uniqueKeysWithValues: allCases.map { tab in
        (tab, [false, true].map { tab.makeIcon(isSelected: $0) })
    })

    private func makeIcon(isSelected: Bool) -> UIImage {
        if self == .feed {
            return Self.artworkIcon(named: "HomeTabIcon", isSelected: isSelected)
        }
        if self == .profile {
            return isSelected
                ? Self.artworkIcon(named: "ProfileTabIcon", isSelected: true)
                : Self.profileOutlineIcon()
        }
        let configuration = UIImage.SymbolConfiguration(pointSize: 25, weight: .regular)
        let name: String
        switch self {
        case .match: name = isSelected ? "pawprint.fill" : "pawprint"
        case .maps: name = isSelected ? "map.fill" : "map"
        case .feed: name = isSelected ? "house.fill" : "house"
        case .chats: name = isSelected ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right"
        case .profile: name = isSelected ? "person.fill" : "person"
        }
        let symbol = UIImage(systemName: name, withConfiguration: configuration)!
            .withTintColor(.black, renderingMode: .alwaysOriginal)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 28))
        return renderer.image { _ in
            let scale = min(28 / symbol.size.width, 26 / symbol.size.height)
            let size = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
            symbol.draw(in: CGRect(x: (30 - size.width) / 2, y: (28 - size.height) / 2, width: size.width, height: size.height))
        }.withRenderingMode(.alwaysOriginal)
    }

    private static func profileOutlineIcon() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 30, height: 28)).image { _ in
            UIColor.black.setStroke()
            let outerCircle = UIBezierPath(ovalIn: CGRect(x: 1.8, y: 0.8, width: 26.4, height: 26.4))
            outerCircle.lineWidth = 1.6
            outerCircle.stroke()

            let head = UIBezierPath(ovalIn: CGRect(x: 11, y: 5.2, width: 8, height: 8))
            head.lineWidth = 1.6
            head.stroke()

            // Keep the entire shoulder outline inset from the outer ring,
            // including a visible gap beneath the curved base.
            let shoulders = UIBezierPath()
            shoulders.move(to: CGPoint(x: 11.5, y: 15))
            shoulders.addQuadCurve(to: CGPoint(x: 18.5, y: 15), controlPoint: CGPoint(x: 15, y: 17.3))
            shoulders.addQuadCurve(to: CGPoint(x: 21.5, y: 20), controlPoint: CGPoint(x: 21.5, y: 16.8))
            shoulders.addCurve(to: CGPoint(x: 8.5, y: 20), controlPoint1: CGPoint(x: 20, y: 24), controlPoint2: CGPoint(x: 10, y: 24))
            shoulders.addQuadCurve(to: CGPoint(x: 11.5, y: 15), controlPoint: CGPoint(x: 8.5, y: 16.8))
            shoulders.close()
            shoulders.lineWidth = 1.6
            shoulders.lineJoinStyle = .round
            shoulders.stroke()
        }.withRenderingMode(.alwaysOriginal)
    }

    private static func artworkIcon(named name: String, isSelected: Bool) -> UIImage {
        // Use the supplied artwork unchanged for the filled state. Derive the
        // outline from its alpha silhouette so both states have identical geometry.
        let artwork = UIImage(named: name)!
            .withTintColor(.black, renderingMode: .alwaysOriginal)
        var interior: UIImage?
        if !isSelected, let source = CIImage(image: artwork) {
            let erosion = CIFilter.morphologyMinimum()
            erosion.inputImage = source
            erosion.radius = 7
            if let output = erosion.outputImage,
               let cgImage = CIContext().createCGImage(output, from: source.extent) {
                interior = UIImage(cgImage: cgImage)
            }
        }
        return UIGraphicsImageRenderer(size: CGSize(width: 30, height: 28)).image { _ in
            let rect = name == "ProfileTabIcon"
                ? CGRect(x: 1, y: 0, width: 28, height: 28)
                : CGRect(x: 0, y: -1, width: 30, height: 30)
            artwork.draw(in: rect)
            interior?.draw(in: rect, blendMode: .destinationOut, alpha: 1)
        }.withRenderingMode(.alwaysOriginal)
    }
}
