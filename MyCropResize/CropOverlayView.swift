import SwiftUI

struct CropOverlayView: View {
    @Binding var cropRect: CGRect
    let imageRect: CGRect
    let aspectRatio: CGFloat?

    @State private var dragStart: CGPoint = .zero
    @State private var startRect: CGRect = .zero

    private let handleSize: CGFloat = 20

    var body: some View {
        ZStack {
            // Dimming outside crop
            Color.black.opacity(0.45)
                .mask(
                    Rectangle()
                        .overlay(
                            Rectangle()
                                .frame(width: cropRect.width, height: cropRect.height)
                                .position(x: cropRect.midX, y: cropRect.midY)
                                .blendMode(.destinationOut)
                        )
                )
                .allowsHitTesting(false)

            // Crop border
            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .allowsHitTesting(false)

            // Grid lines
            gridLines

            // Drag handle (whole crop rect)
            Color.clear
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .gesture(moveDrag)

            // Corner handles
            cornerHandle(corner: .topLeft)
            cornerHandle(corner: .topRight)
            cornerHandle(corner: .bottomLeft)
            cornerHandle(corner: .bottomRight)
        }
    }

    private var gridLines: some View {
        ZStack {
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: cropRect.width, height: 0.5)
                    .position(x: cropRect.midX, y: cropRect.minY + cropRect.height * CGFloat(i) / 3)
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 0.5, height: cropRect.height)
                    .position(x: cropRect.minX + cropRect.width * CGFloat(i) / 3, y: cropRect.midY)
            }
        }
        .allowsHitTesting(false)
    }

    private var moveDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == .zero {
                    dragStart = value.startLocation
                    startRect = cropRect
                }
                let dx = value.location.x - dragStart.x
                let dy = value.location.y - dragStart.y
                var newRect = startRect.offsetBy(dx: dx, dy: dy)
                newRect = clamp(newRect, size: newRect.size)
                cropRect = newRect
            }
            .onEnded { _ in dragStart = .zero }
    }

    private func cornerHandle(corner: Corner) -> some View {
        let pos = cornerPosition(corner)
        return Rectangle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .position(pos)
            .gesture(cornerDrag(corner: corner))
    }

    private func cornerPosition(_ corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft:     return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:    return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:  return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight: return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    private func cornerDrag(corner: Corner) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == .zero {
                    dragStart = value.startLocation
                    startRect = cropRect
                }
                let dx = value.location.x - dragStart.x
                let dy = value.location.y - dragStart.y
                var newRect = resized(startRect, corner: corner, dx: dx, dy: dy)
                newRect = clamp(newRect, size: newRect.size)
                cropRect = newRect
            }
            .onEnded { _ in dragStart = .zero }
    }

    private func resized(_ rect: CGRect, corner: Corner, dx: CGFloat, dy: CGFloat) -> CGRect {
        let minSize: CGFloat = 40
        var x = rect.minX
        var y = rect.minY
        var w = rect.width
        var h = rect.height

        switch corner {
        case .topLeft:
            let rawDy: CGFloat
            if let ar = aspectRatio {
                rawDy = dx / ar
                x = rect.minX + dx; w = max(minSize, rect.width - dx)
                y = rect.minY + rawDy; h = max(minSize, rect.height - rawDy)
            } else {
                x = rect.minX + dx; w = max(minSize, rect.width - dx)
                y = rect.minY + dy; h = max(minSize, rect.height - dy)
            }
        case .topRight:
            if let ar = aspectRatio {
                let rawDy = -dx / ar
                w = max(minSize, rect.width + dx)
                y = rect.minY + rawDy; h = max(minSize, rect.height - rawDy)
            } else {
                w = max(minSize, rect.width + dx)
                y = rect.minY + dy; h = max(minSize, rect.height - dy)
            }
        case .bottomLeft:
            if let ar = aspectRatio {
                let rawDy = -dx / ar
                x = rect.minX + dx; w = max(minSize, rect.width - dx)
                h = max(minSize, rect.height + rawDy)
            } else {
                x = rect.minX + dx; w = max(minSize, rect.width - dx)
                h = max(minSize, rect.height + dy)
            }
        case .bottomRight:
            if let ar = aspectRatio {
                w = max(minSize, rect.width + dx)
                h = max(minSize, w / ar)
            } else {
                w = max(minSize, rect.width + dx)
                h = max(minSize, rect.height + dy)
            }
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func clamp(_ rect: CGRect, size: CGSize) -> CGRect {
        let x = max(imageRect.minX, min(rect.minX, imageRect.maxX - size.width))
        let y = max(imageRect.minY, min(rect.minY, imageRect.maxY - size.height))
        let w = min(size.width, imageRect.width)
        let h = min(size.height, imageRect.height)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
}
