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

let imageWidth: CGFloat = 640
let imageHeight: CGFloat = 640

extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs =
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            ] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let width = 640
        let height = 640
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        if let context = context, let cgImage = self.cgImage {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }
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

        let resizedImage = image.resize(to: CGSize(width: imageWidth, height: imageHeight))
        guard let cgImage = resizedImage.cgImage else {
            throw RoboflowError.imageConversionFailed
        }

        let requestHandler = VNImageRequestHandler(
            cgImage: cgImage,
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

        let pointer = UnsafeMutablePointer<Float32>(OpaquePointer(multiArray.dataPointer))
        let anchorCount = 8400
        let valuesPerAnchor = 23

        var bestConfidence: Float = 0
        var bestKeypoints: [Keypoint] = []
        var bestBoundingBox: CGRect = .zero

        let keypointNames = ["eye-1", "eye-2", "forehead", "mouth-center", "mouth-1", "mouth-2"]

        for anchor in 0..<anchorCount {
            let baseIndex = anchor * valuesPerAnchor

            let confidence = pointer[baseIndex + 4]  // confidence score
            if confidence < 0.5 { continue }  // skip low confidence detections

            var keypoints: [Keypoint] = []
            var totalConfidence: Float = 0

            for i in 0..<6 {
                let x = pointer[baseIndex + 5 + i * 3]
                let y = pointer[baseIndex + 5 + i * 3 + 1]
                let kpConf = pointer[baseIndex + 5 + i * 3 + 2]

                totalConfidence += kpConf

                let keypoint = Keypoint(
                    name: keypointNames[i],
                    x: CGFloat(x),
                    y: CGFloat(y),
                    confidence: kpConf
                )
                keypoints.append(keypoint)
            }

            if confidence > bestConfidence {
                bestConfidence = confidence
                bestKeypoints = keypoints

                // If bounding box values are included and normalized:
                let cx = pointer[baseIndex + 0]
                let cy = pointer[baseIndex + 1]
                let width = pointer[baseIndex + 2]
                let height = pointer[baseIndex + 3]
                bestBoundingBox = CGRect(
                    x: CGFloat(cx - width / 2),
                    y: CGFloat(cy - height / 2),
                    width: CGFloat(width),
                    height: CGFloat(height)
                )
            }
        }

        return HeadPoseObservation(
            keypoints: bestKeypoints,
            confidence: bestConfidence,
            boundingBox: bestBoundingBox
        )
    }
}

enum RoboflowError: Error {
    case modelNotLoaded
    case imageConversionFailed
    case invalidResponseFormat
}
