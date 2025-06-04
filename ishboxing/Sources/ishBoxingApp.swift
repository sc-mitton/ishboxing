//
//  ishApp.swift
//  ish
//
//  Created by Spencer Mitton on 4/30/25.
//

import AVFoundation
import Foundation
import SwiftUI
import UserNotifications
import WebRTC

@main
struct ishApp: App {
    private let config = WebRTCConfig.default
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var currentMeeting: Meeting?

    init() {
        requestPermissionsIfNeeded()
        registerForPushNotifications()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if supabaseService.isAuthenticated {
                    MainView()
                        .navigationTitle("Ish")
                        .navigationBarTitleDisplayMode(.large)
                } else {
                    PhoneSignInView()
                }
            }
        }
    }

    private func didReceiveRemoteNotification(meetingNotification: MeetingNotification) {
        currentMeeting = meetingNotification.meeting
    }

    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    private func requestPermissionsIfNeeded() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("Camera permission: \(granted)")
            }
        }

        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("Microphone permission: \(granted)")
            }
        }
    }
}

#if canImport(HotSwiftUI)
    @_exported import HotSwiftUI
#elseif canImport(Inject)
    @_exported import Inject
#endif

extension Meeting: Equatable {
    public static func == (lhs: Meeting, rhs: Meeting) -> Bool {
        lhs.id == rhs.id
    }
}
