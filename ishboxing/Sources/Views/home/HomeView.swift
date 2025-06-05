//
//  ishApp.swift
//  ish
//
//  Created by Spencer Mitton on 4/30/25.
//

import SwiftUI
import WebRTC

struct MainView: View {
    @StateObject private var friendManagement = FriendManagement()
    @State private var selectedFriend: User?
    @State private var navigateToFight = false
    @State private var notificationMeeting: Meeting?
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
                    FightInitiationView(
                        friend: friend,
                        meeting: notificationMeeting
                    )
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("MeetingNotification"))
            ) { notification in
                if let meeting = notification.userInfo?["meeting"] as? Meeting {
                    handleMeetingNotification(meeting)
                }
            }
            .task {
                await friendManagement.fetchFriends()
            }
        }
    }

    private func initiateFight(with friend: User) {
        selectedFriend = friend
        navigateToFight = true
    }

    private func handleMeetingNotification(_ meeting: Meeting) {
        notificationMeeting = meeting
        if let fromUserId = friendManagement.friends.first(where: {
            $0.id.uuidString == meeting.from
        }) {
            selectedFriend = fromUserId
        }
        navigateToFight = true
    }
}
