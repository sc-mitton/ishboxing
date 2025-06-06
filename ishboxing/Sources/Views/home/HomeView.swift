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

struct HomeView: View {
    @StateObject private var friendManagement = FriendManagement.shared
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
                            .font(.bangers(size: Text.mainTitle()))
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
                    FriendsListView(onFightInitiated: initiateFight)
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
            .task {
                await friendManagement.fetchFriends()
            }
            .onAppear {
                requestPermissionsIfNeeded()
                registerForPushNotifications()
                setupNotificationObserver()
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
        }
    }

    private func initiateFight(with friend: User) {
        selectedFriend = friend
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
        Task {
            // Request camera permission first
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                print("Camera permission: \(granted)")
            }

            // Then request microphone permission
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                print("Microphone permission: \(granted)")
            }
        }
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FightNotificationReceived"),
            object: nil,
            queue: .main
        ) { notification in
            guard let fight = notification.userInfo?["fight"] as? Fight
            else { return }

            // Find the friend who initiated the fight
            if let friend = friendManagement.friends.first(where: { $0.id.uuidString == fight.from }
            ) {
                self.selectedFriend = friend
                self.notificationFight = fight
                self.navigateToFight = true
            }
        }
    }
}
