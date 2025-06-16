import Foundation
import UIKit
import WebRTC

class HeadPoseDetectionRenderer: NSObject, RTCVideoRenderer {
    private let processingQueue = DispatchQueue(label: "com.ishboxing.headposedetectionrenderer")
    private var isProcessing = false
    private var frameCount = 0
    private let processEveryNFrames = 5  // Process every 5th frame to reduce load
    private let headPoseDetectionService: HeadPoseDetectionService
    private weak var delegate: HeadPoseDetectionDelegate?

    init(
        headPoseDetectionService: HeadPoseDetectionService = HeadPoseDetectionService(),
        delegate: HeadPoseDetectionDelegate
    ) {
        self.headPoseDetectionService = headPoseDetectionService
        super.init()
    }

    func setSize(_ size: CGSize) {
        // Handle size changes if needed
    }

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame,
            !isProcessing
        else { return }

        frameCount += 1
        guard frameCount % processEveryNFrames == 0 else { return }

        isProcessing = true

        processingQueue.async { [weak self] in
            defer { self?.isProcessing = false }

            // Convert RTCVideoFrame to UIImage
            guard let image = self?.convertFrameToImage(frame) else { return }

            // Process the image with keypoint detection
            Task {
                await self?.processKeypoints(image)
            }
        }
    }

    private func processKeypoints(_ image: UIImage) async {
        do {
            let headPose = try await headPoseDetectionService.detectHeadPose(in: image)

            // Update game engine on the main thread
            await MainActor.run {
                delegate?.headPoseDetectionRenderer(self, didUpdateHeadPose: headPose)
            }
        } catch {
            debugPrint("Error processing keypoints: \(error)")
        }
    }

    private func convertFrameToImage(_ frame: RTCVideoFrame) -> UIImage? {
        // Convert RTCVideoFrame to UIImage
        // This will depend on the pixel format of your frame
        // You might need to handle different pixel formats (I420, NV12, etc.)
        // Here's a basic example for I420 format:

        guard let buffer = frame.buffer as? RTCCVPixelBuffer else {
            return nil
        }

        let pixelBuffer = buffer.pixelBuffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

protocol HeadPoseDetectionDelegate: AnyObject {
    func headPoseDetectionRenderer(
        _ renderer: HeadPoseDetectionRenderer, didUpdateHeadPose headPose: HeadPoseObservation)
}
