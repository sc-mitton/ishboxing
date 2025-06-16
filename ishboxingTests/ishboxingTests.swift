//
//  ishboxingTests.swift
//  ishboxingTests
//
//  Created by Spencer Mitton on 6/3/25.
//

import CoreML
import SwiftUI
import Testing
import UIKit
import Vision

@testable import ishboxing

struct ishboxingTests {

    @Test func testFacePoseModelOnImage() async throws {
        // Load image from the test bundle
        // Dummy class to get the test bundle
        final class ishboxingTestsClass: NSObject {}

        let bundle = Bundle(for: ishboxingTestsClass.self)

        guard let imageURL = bundle.url(forResource: "image", withExtension: "jpeg"),
            let cgImage = UIImage(contentsOfFile: imageURL.path)?.cgImage
        else {
            throw NSError(
                domain: "TestError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load image.jpeg"])
        }

        let image = UIImage(cgImage: cgImage)

        let headPoseDetectionService = HeadPoseDetectionService()
        let headPose = try await headPoseDetectionService.detectHeadPose(
            in: image.resize(to: CGSize(width: 640, height: 640)))

        print("✅ Model output: \(headPose)")
    }
}
