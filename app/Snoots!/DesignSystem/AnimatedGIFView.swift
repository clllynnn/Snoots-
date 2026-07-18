import ImageIO
import SwiftUI
import UIKit

final class FlexibleAnimatedImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        .zero
    }
}

struct AnimatedGIFView: UIViewRepresentable {
    let sourceName: String
    let fallbackImageName: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> FlexibleAnimatedImageView {
        let imageView = FlexibleAnimatedImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.image = UIImage(named: fallbackImageName)
        context.coordinator.load(sourceName: sourceName, into: imageView)
        return imageView
    }

    func updateUIView(_ imageView: FlexibleAnimatedImageView, context: Context) {
        if imageView.image == nil {
            imageView.image = UIImage(named: fallbackImageName)
        }
        context.coordinator.load(sourceName: sourceName, into: imageView)
    }

    static func dismantleUIView(_ imageView: FlexibleAnimatedImageView, coordinator: Coordinator) {
        coordinator.cancel()
    }

    @MainActor
    final class Coordinator {
        private var loadedSourceName: String?
        private var loadingTask: Task<Void, Never>?

        func load(sourceName: String, into imageView: FlexibleAnimatedImageView) {
            guard loadedSourceName != sourceName else { return }
            loadedSourceName = sourceName
            loadingTask?.cancel()

            loadingTask = Task {
                let result = await Task.detached(priority: .userInitiated) {
                    SendableImage(image: AnimatedGIFView.animatedImage(sourceName: sourceName))
                }.value

                guard !Task.isCancelled,
                      loadedSourceName == sourceName,
                      let image = result.image else { return }
                imageView.image = image
            }
        }

        func cancel() {
            loadingTask?.cancel()
            loadingTask = nil
        }
    }

    private static func animatedImage(sourceName: String) -> UIImage? {
        guard
            let data = gifData(sourceName: sourceName),
            let source = CGImageSourceCreateWithData(data as CFData, nil)
        else {
            return nil
        }

        var frames: [UIImage] = []
        var totalDuration = 0.0

        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: image))
            totalDuration += frameDuration(source: source, index: index)
        }

        guard !frames.isEmpty else { return nil }
        return UIImage.animatedImage(with: frames, duration: max(totalDuration, 0.1))
    }

    private static func gifData(sourceName: String) -> Data? {
        if let assetData = NSDataAsset(name: sourceName)?.data {
            return assetData
        }

        guard let resourceURL = Bundle.main.url(forResource: sourceName, withExtension: "gif") else {
            return nil
        }
        return try? Data(contentsOf: resourceURL)
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any]
        else {
            return 0.1
        }

        let unclampedDelay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval
        let delay = gifProperties[kCGImagePropertyGIFDelayTime as String] as? TimeInterval
        return max(unclampedDelay ?? delay ?? 0.1, 0.02)
    }
}

private struct SendableImage: @unchecked Sendable {
    let image: UIImage?
}
