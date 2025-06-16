import Accelerate
import CoreML
import Foundation
import UIKit
import Vision

// Add this struct to represent keypoints

struct HeadPoseObservation {
    let keypoints: [Keypoint]
    let confidence: Float
    let boundingBox: CGRect
}

struct Keypoint {
    let name: String
    let x: CGFloat
    let y: CGFloat
    let confidence: Float
}

class HeadPoseDetectionService {
    private var model: FacePose?
    private var visionModel: VNCoreMLModel?

    init() {
        loadModel()
    }

    private func loadModel() {
        do {
            print("📱 Attempting to load FacePose model...")
            model = try FacePose(configuration: MLModelConfiguration())
            visionModel = try VNCoreMLModel(for: model!.model)
            print("✅ Successfully loaded FacePose model")
        } catch {
            print("❌ Failed to load CoreML model: \(error)")
        }
    }

    func detectHeadPose(in image: UIImage) async throws -> HeadPoseObservation {
        guard let visionModel = visionModel else {
            throw RoboflowError.modelNotLoaded
        }

        let requestHandler = VNImageRequestHandler(
            cgImage: image.cgImage!,
            options: [:]
        )

        let request = VNCoreMLRequest(model: visionModel)

        do {
            try requestHandler.perform([request])
        } catch {
            throw RoboflowError.invalidResponseFormat
        }

        if let results = request.results {
            if let firstResult = results.first as? VNCoreMLFeatureValueObservation {
                return processCoreMLFeatureValue(firstResult)
            } else {
                throw RoboflowError.invalidResponseFormat
            }
        } else {
            throw RoboflowError.invalidResponseFormat
        }
    }

    private func processCoreMLFeatureValue(_ observation: VNCoreMLFeatureValueObservation)
        -> HeadPoseObservation
    {
        let featureValue = observation.featureValue
        guard let multiArray = featureValue.multiArrayValue else {
            return HeadPoseObservation(keypoints: [], confidence: 0.0, boundingBox: .zero)
        }

        let shape = multiArray.shape.map { $0.intValue }  // [1, 23, 8400]
        let strides = multiArray.strides.map { $0.intValue }  // [193200, 8400, 1]
        let pointer = UnsafeMutablePointer<Float32>(OpaquePointer(multiArray.dataPointer))

        let anchorCount = shape[2]  // 8400
        let keypointNames = ["eye-1", "eye-2", "forehead", "mouth-center", "mouth-1", "mouth-2"]

        func sigmoid(_ x: Float32) -> Float32 {
            return 1.0 / (1.0 + exp(-x))
        }

        var bestConfidence: Float = 0
        var bestAnchorIndex: Int? = nil

        // Find the anchor with the highest objectness confidence
        for anchor in 0..<anchorCount {
            let confidenceIndex = 4 * strides[1] + anchor * strides[2]
            let rawConf = pointer[confidenceIndex]
            let conf = sigmoid(rawConf)

            if conf > bestConfidence {
                bestConfidence = conf
                bestAnchorIndex = anchor
            }
        }

        // If no good anchor found, return empty
        guard let bestAnchor = bestAnchorIndex else {
            return HeadPoseObservation(keypoints: [], confidence: 0.0, boundingBox: .zero)
        }

        // Extract bounding box
        let xCenter = pointer[0 * strides[1] + bestAnchor * strides[2]]
        let yCenter = pointer[1 * strides[1] + bestAnchor * strides[2]]
        let width = pointer[2 * strides[1] + bestAnchor * strides[2]]
        let height = pointer[3 * strides[1] + bestAnchor * strides[2]]

        let boundingBox = CGRect(
            x: CGFloat(xCenter - width / 2),
            y: CGFloat(yCenter - height / 2),
            width: CGFloat(width),
            height: CGFloat(height)
        )

        // Extract 6 keypoints
        var keypoints: [Keypoint] = []

        for i in 0..<6 {
            let x = pointer[(5 + i * 3) * strides[1] + bestAnchor * strides[2]]
            let y = pointer[(6 + i * 3) * strides[1] + bestAnchor * strides[2]]
            let conf = pointer[(7 + i * 3) * strides[1] + bestAnchor * strides[2]]
            keypoints.append(
                Keypoint(
                    name: keypointNames[i],
                    x: CGFloat(x),
                    y: CGFloat(y),
                    confidence: conf
                ))
        }

        return HeadPoseObservation(
            keypoints: keypoints,
            confidence: bestConfidence,
            boundingBox: boundingBox
        )
    }
}

enum RoboflowError: Error {
    case modelNotLoaded
    case imageConversionFailed
    case invalidResponseFormat
}
