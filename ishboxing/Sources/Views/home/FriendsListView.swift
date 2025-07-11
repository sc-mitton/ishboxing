import SwiftSVG
import SwiftUI

struct FriendsListView: View {
    let onMatchInitiated: (User) -> Void
    @StateObject private var friendManagement = FriendManagement.shared
    @State private var showAddFriendModalView = false

    var body: some View {
        VStack(spacing: 0) {
            FriendsListHeader(showAddFriendModalView: $showAddFriendModalView)
            FriendsListContent(
                friendManagement: friendManagement,
                onMatchInitiated: onMatchInitiated
            )
        }
        .background(Color(.systemGray6))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: -4)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(isPresented: $showAddFriendModalView) {
            AddFriendModalView(
                friendManagement: friendManagement,
                onClose: {
                    showAddFriendModalView = false
                }
            )
            .presentationBackground(.clear)
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        }
    }
}

private struct FriendsListHeader: View {
    @Binding var showAddFriendModalView: Bool

    var body: some View {
        HStack {
            Text("Friends ")
                .font(.bangers(size: 26))
                .foregroundColor(.ishRed)
            Spacer()
            Button(action: { showAddFriendModalView = true }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.ishRed)
                    .font(.system(size: 24))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal)
        .background(Color(.systemGray6))
    }
}

private struct FriendsListContent: View {
    @ObservedObject var friendManagement: FriendManagement
    let onMatchInitiated: (User) -> Void

    var body: some View {
        if friendManagement.isLoading {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading friends...")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(Color.clear))
            .refreshable {
                await friendManagement.fetchFriends()
            }
        } else if let error = friendManagement.errorMessage {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Failed to load friends")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: {
                        Task {
                            await friendManagement.fetchFriends()
                        }
                    }) {
                        Text("Retry")
                            .font(.bangers(size: 18))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.ishRed)
                            .cornerRadius(12)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(Color.clear))
            .refreshable {
                await friendManagement.fetchFriends()
            }
        } else {
            List {
                if friendManagement.friends.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No friends yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Add some friends to start boxing!")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(friendManagement.friends) { friendItem in
                        FriendListItem(
                            friendItem: friendItem,
                            onMatchInitiated: onMatchInitiated,
                            friendManagement: friendManagement
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.visible, edges: .bottom)
                        .listRowSeparatorTint(Color.gray.opacity(0.3))
                    }
                }
            }
            .listStyle(PlainListStyle())
            .background(Color(Color.clear))
            .refreshable {
                await friendManagement.fetchFriends()
            }
        }
    }
}

private struct FriendListItem: View {
    let friendItem: FriendItem
    let onMatchInitiated: (User) -> Void
    @ObservedObject var friendManagement: FriendManagement

    var body: some View {
        HStack {
            Text(friendItem.user.username)
                .font(.headline)
            Spacer()

            switch friendItem.status {
            case .confirmed:
                Button(action: {
                    onMatchInitiated(friendItem.user)
                }) {
                    Image("glove")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .scaleEffect(x: -1, y: 1)  // Flip horizontally
                        .padding(8)
                        .background(Color.ishRed)
                        .clipShape(Circle())
                        .shadow(color: .ishRed.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            case .pending:
                Button(action: {
                    if let requestId = friendItem.requestId {
                        Task {
                            try? await friendManagement.confirmFriendRequest(requestId)
                        }
                    }
                }) {
                    Text("Confirm ")
                        .font(.bangers(size: 20))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.ishBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .ishBlue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            case .requested:
                Text("Pending ")
                    .font(.bangers(size: 20))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(Color.clear))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    debugPrint("Friend: \(friendItem)")
                    debugPrint("Deleting friend: \(friendItem.user.id)")
                    try? await friendManagement.deleteFriend(friendItem.user.id)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
