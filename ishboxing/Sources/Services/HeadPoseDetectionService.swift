import CoreML
import Foundation
import UIKit
import Vision

class HeadPoseDetectionService {
    private var model: FacePose?
    private var visionModel: VNCoreMLModel?

    init() {
        loadModel()
    }

    private func loadModel() {
        do {
            model = try FacePose(configuration: MLModelConfiguration())
        } catch {
            print("❌ Failed to load CoreML model: \(error)")
        }
    }

    func detectHeadPose(in image: UIImage) async throws -> [Keypoint] {
        guard let model = model else {
            throw RoboflowError.modelNotLoaded
        }

        let requestHandler = VNImageRequestHandler(
            cgImage: image.resize(to: CGSize(width: 640, height: 640)).cgImage!,
            options: [:]
        )

        let request = VNCoreMLRequest(model: try VNCoreMLModel(for: model.model))

        // Perform the request
        try requestHandler.perform([request])

        // Get the results
        guard let results = request.results as? [VNRecognizedPointsObservation],
            let firstResult = results.first
        else {
            throw RoboflowError.invalidResponseFormat
        }

        let keypoints = try firstResult.recognizedPoints(forGroupKey: .all)

        // Convert VNRecognizedKeypoints to our Keypoint struct
        return keypoints.map { (key, point) in
            Keypoint(
                name: key.rawValue,
                x: CGFloat(point.location.x),
                y: CGFloat(point.location.y),
                confidence: Float(point.confidence)
            )
        }
    }
}

enum RoboflowError: Error {
    case modelNotLoaded
    case imageConversionFailed
    case invalidResponseFormat
}
