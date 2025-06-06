//
//  ishBoxingApp.swift
//  ish
//
//  Created by Spencer Mitton on 4/30/25.
//

import AVFoundation
import Foundation
import SwiftUI
import UserNotifications
import WebRTC

struct OTPRoute: Hashable {
    let phoneNumber: String
}

@main
struct ishBoxingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    private let config = WebRTCConfig.default
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var currentMatch: Match?
    @StateObject private var router = Router()
    @StateObject private var userManagement = UserManagement()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                Group {
                    if supabaseService.isAuthenticated {
                        HomeView()
                            .navigationBarBackButtonHidden(true)
                    } else {
                        PhoneSignInView()
                    }
                }
                .navigationDestination(for: String.self) { route in
                    switch route {
                    case "username":
                        UsernameSetupView()
                    case "otp":
                        OTPVerificationView()
                    case "phone":
                        PhoneSignInView()
                    default:
                        EmptyView()
                    }
                }
            }
            .environmentObject(router)
            .environmentObject(userManagement)
        }
    }
}

#if canImport(HotSwiftUI)
    @_exported import HotSwiftUI
#elseif canImport(Inject)
    @_exported import Inject
#endif

extension Match: Equatable {
    public static func == (lhs: Match, rhs: Match) -> Bool {
        lhs.id == rhs.id
    }
}
