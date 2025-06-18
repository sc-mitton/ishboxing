import Foundation
import UIKit
import WebRTC

// Import Constants
@_exported import struct Foundation.CGFloat

class HeadPoseDetectionRenderer: NSObject, RTCVideoRenderer, ObservableObject {
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

        let rotation: CGFloat

        switch UIDevice.current.orientation {
        case .portrait:
            rotation = -0.5 * CGFloat.pi
        case .portraitUpsideDown:
            rotation = -0.5 * CGFloat.pi
        case .landscapeLeft:
            rotation = 1.0 * CGFloat.pi
        case .landscapeRight:
            rotation = 0.0 * CGFloat.pi
        default:
            rotation = 0.0 * CGFloat.pi
        }

        let targetSize = CGSize(
            width: Constants.HeadPoseDetection.targetSize,
            height: Constants.HeadPoseDetection.targetSize)
        let scaleX = targetSize.width / ciImage.extent.width
        let scaleY = targetSize.height / ciImage.extent.height
        let scaledRotatedImage =
            ciImage
            .cropped(to: ciImage.extent)
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(rotationAngle: rotation))

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
