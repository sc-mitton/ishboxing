import CoreML
import Foundation
import UIKit
import Vision

class RoboflowService {
    private var model: MLModel?
    private var visionModel: VNCoreMLModel?

    init() {
        loadModel()
    }

    private func loadModel() {
        do {
            // Load the CoreML model from the bundle
            guard
                let modelURL = Bundle.main.url(forResource: "YOLOv8Pose", withExtension: "mlmodelc")
            else {
                print("❌ Failed to find CoreML model in bundle")
                return
            }

            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use all available compute units (CPU, Neural Engine, GPU)

            model = try MLModel(contentsOf: modelURL, configuration: config)
            visionModel = try VNCoreMLModel(for: model!)
        } catch {
            print("❌ Failed to load CoreML model: \(error)")
        }
    }

    func detectKeypoints(in image: UIImage) async throws -> [Keypoint] {
        guard let visionModel = visionModel else {
            throw RoboflowError.modelNotLoaded
        }

        // Create a request to perform pose detection
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            if let error = error {
                print("❌ Vision request failed: \(error)")
            }
        }

        // Configure the request
        request.imageCropAndScaleOption = .scaleFit

        // Create a handler to process the image
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])

        // Perform the request
        try handler.perform([request])

        // Process the results
        guard let results = request.results as? [VNRecognizedPointsObservation] else {
            throw RoboflowError.invalidResponseFormat
        }

        // Convert the results to keypoints
        var keypoints: [Keypoint] = []

        for observation in results {
            // Get the recognized points
            guard let recognizedPoints = try? observation.recognizedPoints(forGroupKey: .all) else {
                continue
            }

            // Convert each point to a keypoint
            for (key, point) in recognizedPoints {
                if point.confidence > 0.1 {  // Filter out low confidence points
                    let keypoint = Keypoint(
                        name: key.rawValue,
                        x: CGFloat(point.location.x),
                        y: CGFloat(point.location.y),
                        confidence: Float(point.confidence)
                    )
                    keypoints.append(keypoint)
                }
            }
        }

        return keypoints
    }
}

enum RoboflowError: Error {
    case modelNotLoaded
    case imageConversionFailed
    case invalidResponseFormat
}
