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
    @State private var showAddFriendModal = false
    @State private var newFriendUsername = ""
    @State private var addFriendError: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats section (top third)
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: UIScreen.main.bounds.height / 3)
                    .overlay(
                        VStack {
                            Text("Stats")
                                .font(.title)
                                .padding()
                            // Placeholder for future stats
                            Text("Wins: 0")
                            Text("Streak: 0")
                        }
                    )

                // Friends list section
                List {
                    Section(
                        header:
                            HStack {
                                Text("Friends")
                                Spacer()
                                Button(action: { showAddFriendModal = true }) {
                                    Image(systemName: "person.badge.plus")
                                }
                            }
                    ) {
                        if friendManagement.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if let error = friendManagement.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if friendManagement.friends.isEmpty {
                            Text("No friends yet")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(friendManagement.friends) { friend in
                                HStack {
                                    Text(friend.username)
                                    Spacer()
                                    Button(action: {
                                        initiateFight(with: friend)
                                    }) {
                                        Text("Fight")
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.red)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationDestination(isPresented: $navigateToFight) {
                if let friend = selectedFriend {
                    FightInitiationView(
                        friend: friend,
                        meeting: notificationMeeting
                    )
                }
            }
            .overlay {
                if showAddFriendModal {
                    AddFriendModal(
                        friendManagement: friendManagement,
                        onClose: {
                            showAddFriendModal = false
                        }
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
