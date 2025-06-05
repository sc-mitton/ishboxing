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
    @State private var currentFight: Fight?
    @State private var navigationPath = NavigationPath()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                Group {
                    if supabaseService.isAuthenticated {
                        MainView()
                            .navigationBarBackButtonHidden(true)
                    } else {
                        PhoneSignInView(navigationPath: $navigationPath)
                    }
                }
                .navigationDestination(for: String.self) { route in
                    switch route {
                    case "username":
                        UsernameSetupView(navigationPath: $navigationPath)
                    default:
                        EmptyView()
                    }
                }
                .navigationDestination(for: OTPRoute.self) { route in
                    OTPVerificationView(
                        phoneNumber: route.phoneNumber, navigationPath: $navigationPath)
                }
            }
        }
    }

    private func didReceiveRemoteNotification(fightNotification: FightNotification) {
        currentFight = fightNotification.fight
    }
}

#if canImport(HotSwiftUI)
    @_exported import HotSwiftUI
#elseif canImport(Inject)
    @_exported import Inject
#endif

extension Fight: Equatable {
    public static func == (lhs: Fight, rhs: Fight) -> Bool {
        lhs.id == rhs.id
    }
}
