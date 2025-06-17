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
    @StateObject private var userManagement = UserManagement()
    @State private var selectedFriend: User?
    @State private var notificationMatch: Match?
    @State private var showMatchRequestModal = false
    @State private var newFriendUsername = ""
    @State private var addFriendError: String?
    @State private var showMatchView = false
    @State private var wins: Int = 0
    @State private var losses: Int = 0
    @State private var streak: Int = 0

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
                                Text("Record")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("\(wins)-\(losses)")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }

                            VStack {
                                Text("Streak")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("\(streak)")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(height: UIScreen.main.bounds.height / 3)

                    // Friends list section
                    FriendsListView(onMatchInitiated: initiateMatch)
                }
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { showMatchView && selectedFriend != nil },
                    set: {
                        if !$0 {
                            showMatchView = false
                            selectedFriend = nil
                            notificationMatch = nil
                        }
                    }
                )
            ) {
                MatchView(friend: selectedFriend!, match: notificationMatch) {
                    showMatchView = false
                    selectedFriend = nil
                    notificationMatch = nil
                }
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { showMatchRequestModal },
                    set: {
                        if !$0 {
                            showMatchRequestModal = false
                        }
                    }
                )
            ) {
                MatchRequestModalView(match: notificationMatch!) {
                    showMatchView = true
                    showMatchRequestModal = false
                }
                .presentationBackground(.clear)
                .transaction { transaction in
                    transaction.disablesAnimations = true
                }
            }

            .task {
                await friendManagement.fetchFriends()
                await fetchStats()
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

    private func initiateMatch(with friend: User) {
        selectedFriend = friend
        showMatchView = true
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
        // Remove any existing observer first
        NotificationCenter.default.removeObserver(self)

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MatchNotificationReceived"),
            object: nil,
            queue: .main
        ) { notification in
            guard let match = notification.userInfo?["match"] as? Match else {
                return
            }

            // Find the friend who initiated the match
            if let friend = self.friendManagement.unifiedFriends.first(where: {
                $0.user.id.uuidString == match.from.id.uuidString
            }) {
                self.selectedFriend = friend.user
                self.notificationMatch = match

                // Only show the match
                debugPrint("User is in match: \(self.userManagement.isInMatch)")
                if !self.userManagement.isInMatch {
                    self.showMatchRequestModal = true
                }
            }
        }
    }

    private func fetchStats() async {
        do {
            let stats = try await SupabaseService.shared.getMatchStats()
            wins = stats.wins
            losses = stats.losses
            streak = stats.streak
        } catch {
            print("Error fetching stats: \(error)")
        }
    }
}
