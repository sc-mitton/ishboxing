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
        Path(points: points, isLocal: isLocal)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        isLocal ? Color.ishBlue : Color.red,
                        isLocal ? Color.ishBlue.opacity(0.5) : Color.red.opacity(0.5),
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(
                    lineWidth: 12,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .blur(radius: 3)
            .overlay(
                Path(points: points, isLocal: isLocal)
                    .stroke(
                        isLocal ? Color.ishBlue : Color.red,
                        style: StrokeStyle(
                            lineWidth: 8,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            )
    }
}
