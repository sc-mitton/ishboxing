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
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use all available compute units
            model = try FacePose(configuration: config)

            guard let model = model else {
                print("❌ Model is nil after initialization")
                return
            }

            visionModel = try VNCoreMLModel(for: model.model)
            print("✅ Successfully loaded FacePose model")
        } catch {
            print("❌ Failed to load CoreML model: \(error)")
        }
    }

    private func isModelReady() -> Bool {
        return model != nil && visionModel != nil
    }

    func detectHeadPose(in image: UIImage) async throws -> HeadPoseObservation {
        guard isModelReady() else {
            throw RoboflowError.modelNotLoaded
        }

        guard let cgImage = image.cgImage else {
            throw RoboflowError.imageConversionFailed
        }

        let requestHandler = VNImageRequestHandler(
            cgImage: cgImage,
            options: [:]
        )

        let request = VNCoreMLRequest(model: visionModel!)

        do {
            try requestHandler.perform([request])
        } catch {
            print("❌ Vision request handler failed: \(error)")
            throw RoboflowError.invalidResponseFormat
        }

        guard let results = request.results else {
            throw RoboflowError.invalidResponseFormat
        }

        guard let firstResult = results.first as? VNCoreMLFeatureValueObservation else {
            throw RoboflowError.invalidResponseFormat
        }

        return processCoreMLFeatureValue(firstResult)
    }

    private func processCoreMLFeatureValue(_ observation: VNCoreMLFeatureValueObservation)
        -> HeadPoseObservation
    {
        // The observation result is shaped 1 x 23 x 8440
        // 6 keypoints x 3 values (x, y, confidence) = 18 + 5 for the bounding box (x, y, width, height, confidence) = 23
        // We need to extract the keypoints from the observation to the proper shape

        let featureValue = observation.featureValue
        guard let multiArray = featureValue.multiArrayValue else {
            return HeadPoseObservation(keypoints: [], confidence: 0.0, boundingBox: .zero)
        }

        let shape = multiArray.shape.map { $0.intValue }  // [1, 23, 8400]
        let strides = multiArray.strides.map { $0.intValue }  // [193200, 8400, 1]

        // Safety check for valid shape and strides
        guard shape.count >= 3, strides.count >= 3 else {
            return HeadPoseObservation(keypoints: [], confidence: 0.0, boundingBox: .zero)
        }

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

            // Safety check for array bounds
            guard confidenceIndex >= 0 && confidenceIndex < multiArray.count else {
                continue
            }

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

        // Extract bounding box with safety checks
        let xCenterIndex = 0 * strides[1] + bestAnchor * strides[2]
        let yCenterIndex = 1 * strides[1] + bestAnchor * strides[2]
        let widthIndex = 2 * strides[1] + bestAnchor * strides[2]
        let heightIndex = 3 * strides[1] + bestAnchor * strides[2]

        guard xCenterIndex >= 0 && xCenterIndex < multiArray.count,
            yCenterIndex >= 0 && yCenterIndex < multiArray.count,
            widthIndex >= 0 && widthIndex < multiArray.count,
            heightIndex >= 0 && heightIndex < multiArray.count
        else {
            return HeadPoseObservation(keypoints: [], confidence: 0.0, boundingBox: .zero)
        }

        let xCenter = pointer[xCenterIndex]
        let yCenter = pointer[yCenterIndex]
        let width = pointer[widthIndex]
        let height = pointer[heightIndex]

        let boundingBox = CGRect(
            x: CGFloat(xCenter - width / 2),
            y: CGFloat(yCenter - height / 2),
            width: CGFloat(width),
            height: CGFloat(height)
        )

        // Extract 6 keypoints with safety checks
        var keypoints: [Keypoint] = []

        for i in 0..<6 {
            let xIndex = (5 + i * 3) * strides[1] + bestAnchor * strides[2]
            let yIndex = (6 + i * 3) * strides[1] + bestAnchor * strides[2]
            let confIndex = (7 + i * 3) * strides[1] + bestAnchor * strides[2]

            guard xIndex >= 0 && xIndex < multiArray.count,
                yIndex >= 0 && yIndex < multiArray.count,
                confIndex >= 0 && confIndex < multiArray.count
            else {
                continue
            }

            let x = pointer[xIndex]
            let y = pointer[yIndex]
            let conf = pointer[confIndex]

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
