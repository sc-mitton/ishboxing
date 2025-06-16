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

        let keypointCount = multiArray.count / 3
        var keypoints: [Keypoint] = []
        var totalConfidence: Float = 0.0

        for i in 0..<keypointCount {
            let baseIndex = i * 3
            let x = CGFloat(multiArray[baseIndex].floatValue) * imageWidth
            let y = CGFloat(multiArray[baseIndex + 1].floatValue) * imageHeight
            let confidence = multiArray[baseIndex + 2].floatValue

            let keypoint = Keypoint(
                name: "keypoint_\(i)",
                x: x,
                y: y,
                confidence: confidence
            )
            keypoints.append(keypoint)
            totalConfidence += confidence
        }

        let overallConfidence = keypoints.isEmpty ? 0.0 : totalConfidence / Float(keypoints.count)
        let boundingBox = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)

        return HeadPoseObservation(
            keypoints: keypoints,
            confidence: overallConfidence,
            boundingBox: boundingBox
        )
    }
}

enum RoboflowError: Error {
    case modelNotLoaded
    case imageConversionFailed
    case invalidResponseFormat
}
