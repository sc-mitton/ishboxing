import SwiftUI

struct PoseAnnotation: View {
    let headPose: HeadPoseObservation
    let viewSize: CGSize

    // Use a uniform scale to preserve aspect ratio
    private var xScale: CGFloat {
        min(viewSize.width, viewSize.height) / 640.0
    }
    private var yScale: CGFloat {
        min(viewSize.width, viewSize.height) / 640.0
    }

    // Calculate offset to center the annotation
    private var xOffset: CGFloat {
        (viewSize.width - 640.0 * xScale) / 2.0
    }
    private var yOffset: CGFloat {
        (viewSize.height - 640.0 * yScale) / 2.0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw bounding box
                Rectangle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(
                        width: headPose.boundingBox.width * xScale,
                        height: headPose.boundingBox.height * yScale
                    )
                    .position(
                        x: headPose.boundingBox.midX * xScale + xOffset,
                        y: headPose.boundingBox.midY * yScale + yOffset
                    )
                    .scaleEffect(x: -1, y: 1, anchor: .center)  // -1 because we mirror the image in the video view

                // Draw keypoints
                ForEach(headPose.keypoints, id: \.name) { keypoint in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 4, height: 4)
                        .position(
                            x: keypoint.x * xScale + xOffset,
                            y: keypoint.y * yScale + yOffset
                        )
                        .scaleEffect(x: -1, y: 1, anchor: .center)  // -1 because we mirror the image in the video view
                }
            }
        }
    }
}
