import Foundation
import UIKit
import WebRTC

class HeadPoseDetectionRenderer: NSObject, RTCVideoRenderer {
    private let headPoseDetectionService: HeadPoseDetectionService
    private let ciContext = CIContext(options: [CIContextOption.cacheIntermediates: false])
    weak var delegate: HeadPoseDetectionDelegate?

    private var pendingTask: Task<Void, Never>?
    private var isProcessing = false

    init(
        headPoseDetectionService: HeadPoseDetectionService = HeadPoseDetectionService(),
        delegate: HeadPoseDetectionDelegate
    ) {
        self.headPoseDetectionService = headPoseDetectionService
        self.delegate = delegate
        super.init()
    }

    deinit {
        pendingTask?.cancel()
    }

    func setSize(_ size: CGSize) {
        // Handle size changes if needed
    }

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame else { return }

        // Cancel any pending task before starting a new one
        pendingTask?.cancel()
        pendingTask = nil

        // Prevent overlapping tasks
        guard !isProcessing else { return }
        isProcessing = true

        guard let image = convertFrameToImage(frame) else {
            isProcessing = false
            return
        }

        pendingTask = Task { [weak self] in
            guard let self = self else { return }
            await self.processKeypoints(image)
        }
    }

    private func processKeypoints(_ image: UIImage) async {
        defer { isProcessing = false }

        do {
            let headPose = try await headPoseDetectionService.detectHeadPose(in: image)
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.delegate?.headPoseDetectionRenderer(self, didUpdateHeadPose: headPose)
            }
        } catch {
            debugPrint("❌ Error processing keypoints: \(error)")
        }
    }

    private func convertFrameToImage(_ frame: RTCVideoFrame) -> UIImage? {
        guard let buffer = frame.buffer as? RTCCVPixelBuffer else {
            return nil
        }

        let pixelBuffer = buffer.pixelBuffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let targetSize = CGSize(width: 640, height: 640)
        let scaleX = targetSize.width / ciImage.extent.width
        let scaleY = targetSize.height / ciImage.extent.height
        let scaledRotatedImage =
            ciImage
            .cropped(to: ciImage.extent)
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(rotationAngle: -0.5 * .pi))

        guard
            let cgImage = ciContext.createCGImage(
                scaledRotatedImage, from: scaledRotatedImage.extent)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

protocol HeadPoseDetectionDelegate: AnyObject {
    func headPoseDetectionRenderer(
        _ renderer: HeadPoseDetectionRenderer, didUpdateHeadPose headPose: HeadPoseObservation)
}
