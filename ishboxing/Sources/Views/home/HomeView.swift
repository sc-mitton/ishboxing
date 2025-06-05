//
//  ishBoxingApp.swift
//  ish
//
//  Created by Spencer Mitton on 4/30/25.
//

import AVFoundation
import SwiftUI
import UserNotifications
import WebRTC

struct MainView: View {
    @StateObject private var friendManagement = FriendManagement()
    @State private var selectedFriend: User?
    @State private var navigateToFight = false
    @State private var notificationFight: Fight?
    @State private var showAddFriendModalView = false
    @State private var newFriendUsername = ""
    @State private var addFriendError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // Full background gradient
                LinearGradient(
                    gradient: Gradient(colors: [.ishDarkBlue, .ishBlue, .ishLightBlue]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Stats section
                    VStack(spacing: 20) {
                        Text("Ish Boxing ")
                            .font(.bangers(size: 38))
                            .foregroundColor(.white)
                            .padding(.top, 16)

                        HStack(spacing: 40) {
                            VStack {
                                Text("Wins")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("0")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }

                            VStack {
                                Text("Streak")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("0")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(height: UIScreen.main.bounds.height / 3)

                    // Friends list section
                    FriendsListView(
                        friendManagement: friendManagement,
                        onFightInitiated: initiateFight
                    )
                }
            }
            .navigationDestination(isPresented: $navigateToFight) {
                if let friend = selectedFriend {
                    FightView(
                        friend: friend,
                        fight: notificationFight
                    )
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("FightNotification"))
            ) { notification in
                if let fight = notification.userInfo?["fight"] as? Fight {
                    handleFightNotification(fight)
                }
            }
            .task {
                await friendManagement.fetchFriends()
            }
            .onAppear {
                requestPermissionsIfNeeded()
                registerForPushNotifications()
            }
        }
    }

    private func initiateFight(with friend: User) {
        selectedFriend = friend
        navigateToFight = true
    }

    private func handleFightNotification(_ fight: Fight) {
        notificationFight = fight
        if let fromUserId = friendManagement.friends.first(where: {
            $0.id.uuidString == fight.from
        }) {
            selectedFriend = fromUserId
        }
        navigateToFight = true
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
