//
//  ishApp.swift
//  ish
//
//  Created by Spencer Mitton on 4/30/25.
//

import SwiftUI
import WebRTC

struct MainView: View {
    @State private var friends: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFriend: User?
    @State private var showFightInitiation = false
    @State private var notificationMeeting: Meeting?

    private var supabaseService = SupabaseService.shared

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
                    Section(header: Text("Friends")) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if friends.isEmpty {
                            Text("No friends yet")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(friends) { friend in
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
            .sheet(isPresented: $showFightInitiation) {
                FightInitiationView(
                    friend: selectedFriend!,
                    meeting: notificationMeeting
                )
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
                await fetchFriends()
            }
        }
    }

    private func fetchFriends() async {
        isLoading = true
        errorMessage = nil

        do {
            friends = try await supabaseService.getFriends()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func initiateFight(with friend: User) {
        selectedFriend = friend
        showFightInitiation = true
    }

    func handleMeetingNotification(_ meeting: Meeting) {
        notificationMeeting = meeting
        if let fromUserId = friends.first(where: { $0.id.uuidString == meeting.from }) {
            selectedFriend = fromUserId
        }
        showFightInitiation = true
    }
}
