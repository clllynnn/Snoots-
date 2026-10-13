import ImageIO
import SwiftUI
import UIKit

struct RegistrationPhotoCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (Data) -> Void

    @State private var zoom: CGFloat = 1
    @State private var gestureZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero
    @State private var exportError = false

    static func previewImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let side = min(geometry.size.width - 40, geometry.size.height * 0.58, 390)
                VStack(spacing: 0) {
                    Spacer(minLength: 20)
                    cropViewport(side: side)
                        .frame(width: side, height: side)
                        .accessibilityLabel("大頭貼裁切預覽")
                    if exportError {
                        Text("照片處理失敗，請重新調整或取消。")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Color(.systemRed))
                            .padding(.top, 12)
                    }
                    Spacer(minLength: 20)
                    Button("確認大頭貼") { confirmCrop(side: side) }
                        .buttonStyle(OnboardingPrimaryButtonStyle(fill: SnootsPalette.primary, cornerRadius: 28))
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(SnootsPalette.canvas)
            .navigationTitle("裁切狗狗大頭貼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", action: onCancel)
                        .accessibilityLabel("取消裁切，返回註冊填寫")
                }
            }
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(SnootsPalette.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(SnootsPalette.navigationActive)
    }

    private func cropViewport(side: CGFloat) -> some View {
        let scale = max(1, min(zoom * gestureZoom, 4))
        let display = displayedSize(side: side, scale: scale)
        let visibleOffset = limitedOffset(
            CGSize(width: offset.width + gestureOffset.width, height: offset.height + gestureOffset.height),
            display: display, side: side
        )

        return ZStack {
            SnootsPalette.divider
            Image(uiImage: image)
                .resizable()
                .frame(width: display.width, height: display.height)
                .offset(visibleOffset)
                .allowsHitTesting(false)
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay {
            CropGrid()
                .stroke(.white.opacity(0.78), lineWidth: 1)
                .shadow(color: .black.opacity(0.45), radius: 1)
                .clipShape(Circle())
                .allowsHitTesting(false)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture()
                .onChanged { gestureOffset = $0.translation }
                .onEnded { value in
                    offset = limitedOffset(
                        CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height),
                        display: display, side: side
                    )
                    gestureOffset = .zero
                }
                .simultaneously(with:
                    MagnificationGesture()
                        .onChanged { gestureZoom = $0 }
                        .onEnded { value in
                            zoom = max(1, min(zoom * value, 4))
                            gestureZoom = 1
                            offset = limitedOffset(offset, display: displayedSize(side: side, scale: zoom), side: side)
                        }
                )
        )
        .overlay {
            Circle()
                .strokeBorder(SnootsPalette.surface.opacity(0.9), lineWidth: 2)
                .allowsHitTesting(false)
        }
    }

    private func displayedSize(side: CGFloat, scale: CGFloat) -> CGSize {
        let fit = max(side / image.size.width, side / image.size.height) * scale
        return CGSize(width: image.size.width * fit, height: image.size.height * fit)
    }

    private func limitedOffset(_ candidate: CGSize, display: CGSize, side: CGFloat) -> CGSize {
        let xLimit = max(0, (display.width - side) / 2)
        let yLimit = max(0, (display.height - side) / 2)
        return CGSize(
            width: min(max(candidate.width, -xLimit), xLimit),
            height: min(max(candidate.height, -yLimit), yLimit)
        )
    }

    private func confirmCrop(side: CGFloat) {
        let display = displayedSize(side: side, scale: zoom)
        let cropSide = image.size.width * side / display.width
        let currentOffset = limitedOffset(offset, display: display, side: side)
        let imagePointsPerScreenPoint = image.size.width / display.width
        let origin = CGPoint(
            x: (image.size.width - cropSide) / 2 - currentOffset.width * imagePointsPerScreenPoint,
            y: (image.size.height - cropSide) / 2 - currentOffset.height * imagePointsPerScreenPoint
        )
        let outputSide: CGFloat = 768
        let outputScale = outputSide / cropSide
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let cropped = UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide), format: format).image { _ in
            image.draw(in: CGRect(
                x: -origin.x * outputScale,
                y: -origin.y * outputScale,
                width: image.size.width * outputScale,
                height: image.size.height * outputScale
            ))
        }
        guard let data = cropped.jpegData(compressionQuality: 0.85) else {
            exportError = true
            return
        }
        onConfirm(data)
    }
}

private struct CropGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
            let x = rect.minX + rect.width * fraction
            let y = rect.minY + rect.height * fraction
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}
