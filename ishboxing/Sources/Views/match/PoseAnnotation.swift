import SwiftUI

struct PoseAnnotation: View {
    let headPose: HeadPoseObservation
    let viewSize: CGSize

    private var scaleX: CGFloat {
        viewSize.width / 640.0
    }

    private var scaleY: CGFloat {
        viewSize.height / 640.0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw bounding box
                Rectangle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(
                        width: headPose.boundingBox.width * scaleX,
                        height: headPose.boundingBox.height * scaleY
                    )
                    .position(
                        x: headPose.boundingBox.midX * scaleX,
                        y: headPose.boundingBox.midY * scaleY
                    )

                // Draw keypoints
                ForEach(headPose.keypoints, id: \.name) { keypoint in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 4, height: 4)
                        .position(
                            x: keypoint.x * scaleX,
                            y: keypoint.y * scaleY
                        )
                }
            }
        }
    }
}
