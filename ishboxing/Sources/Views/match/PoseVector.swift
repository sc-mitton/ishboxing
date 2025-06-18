import SwiftUI

struct PoseVector: View {
    let headPositionHistory: [HeadPoseObservation]

    private func calculateDodgeVector() -> (start: CGPoint, end: CGPoint) {
        guard headPositionHistory.count >= 2 else {
            return (CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0))
        }

        // Get the last two head positions using bounding box centers
        let lastBox = headPositionHistory.last!.boundingBox
        let recentBox = headPositionHistory.first!.boundingBox

        // Convert from detection space to normalized coordinates (0-1)
        // Flip x coordinate to match mirrored video view
        let lastCenter = CGPoint(
            x: 1.0 - (lastBox.midX / Constants.HeadPoseDetection.targetSize),  // Flip x coordinate
            y: lastBox.midY / Constants.HeadPoseDetection.targetSize
        )
        let recentCenter = CGPoint(
            x: 1.0 - (recentBox.midX / Constants.HeadPoseDetection.targetSize),  // Flip x coordinate
            y: recentBox.midY / Constants.HeadPoseDetection.targetSize
        )

        // Calculate the vector from the second to last position to the last position
        let dx = lastCenter.x - recentCenter.x
        let dy = lastCenter.y - recentCenter.y

        // Only return significant movements
        let magnitude = sqrt(dx * dx + dy * dy)
        if magnitude > 0.05 {  // Threshold for significant movement
            return (
                CGPoint(x: recentCenter.x, y: recentCenter.y),
                CGPoint(x: lastCenter.x, y: lastCenter.y)
            )
        }

        return (
            CGPoint(x: lastCenter.x, y: lastCenter.y),
            CGPoint(x: lastCenter.x, y: lastCenter.y)
        )  // Return same point if movement is insignificant
    }

    var body: some View {
        GeometryReader { geometry in
            let vector = calculateDodgeVector()
            let startPoint = CGPoint(
                x: vector.start.x * geometry.size.width,
                y: vector.start.y * geometry.size.height
            )
            let endPoint = CGPoint(
                x: vector.end.x * geometry.size.width,
                y: vector.end.y * geometry.size.height
            )

            Canvas { context, size in
                // Draw main line with increased width and opacity
                var linePath = SwiftUI.Path()
                linePath.move(to: startPoint)
                linePath.addLine(to: endPoint)
                context.stroke(linePath, with: .color(.yellow.opacity(0.8)), lineWidth: 5)

                // Draw arrow head with increased size
                let arrowLength: CGFloat = 15
                let arrowAngle: CGFloat = .pi / 6  // 30 degrees

                let dx = endPoint.x - startPoint.x
                let dy = endPoint.y - startPoint.y
                let angle = atan2(dy, dx)

                let arrowPoint1 = CGPoint(
                    x: endPoint.x - arrowLength * cos(angle + arrowAngle),
                    y: endPoint.y - arrowLength * sin(angle + arrowAngle)
                )
                let arrowPoint2 = CGPoint(
                    x: endPoint.x - arrowLength * cos(angle - arrowAngle),
                    y: endPoint.y - arrowLength * sin(angle - arrowAngle)
                )

                var arrowPath = SwiftUI.Path()
                arrowPath.move(to: endPoint)
                arrowPath.addLine(to: arrowPoint1)
                arrowPath.move(to: endPoint)
                arrowPath.addLine(to: arrowPoint2)
                context.stroke(arrowPath, with: .color(.yellow.opacity(0.8)), lineWidth: 5)
            }
        }
    }
}
