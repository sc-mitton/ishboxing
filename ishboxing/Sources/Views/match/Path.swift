import SwiftUI

struct Path: Shape {
    let points: [CGPoint]
    let isLocal: Bool

    func path(in rect: CGRect) -> SwiftUI.Path {
        var path = SwiftUI.Path()

        guard points.count > 1 else { return path }

        path.move(to: points[0])

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }
}

struct GlowingPath: View {
    let points: [CGPoint]
    let isLocal: Bool

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }

            var path = SwiftUI.Path()
            path.move(to: points[0])

            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            // Create gradient stops for the stroke
            let gradient = Gradient(stops: [
                .init(color: (isLocal ? Color.ishBlue : Color.red).opacity(0.0), location: 0),
                .init(color: (isLocal ? Color.ishBlue : Color.red).opacity(1.0), location: 1),
            ])

            // Draw the main stroke with gradient
            context.stroke(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: points[0],
                    endPoint: points.last ?? points[0]
                ),
                style: StrokeStyle(
                    lineWidth: 24,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Draw the glow effect with varying width
            let glowGradient = Gradient(stops: [
                .init(color: (isLocal ? Color.ishBlue : Color.red).opacity(0.0), location: 0),
                .init(color: (isLocal ? Color.ishBlue : Color.red).opacity(0.8), location: 1),
            ])

            // Draw multiple strokes with decreasing width for the glow effect
            for i in 0..<3 {
                let width = 54.0 - Double(i * 4)

                context.stroke(
                    path,
                    with: .linearGradient(
                        glowGradient,
                        startPoint: points[0],
                        endPoint: points.last ?? points[0]
                    ),
                    style: StrokeStyle(
                        lineWidth: width,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
    }
}
