import SwiftUI

struct FriendsListView: View {
    let onMatchInitiated: (User) -> Void
    @StateObject private var friendManagement = FriendManagement.shared
    @State private var showAddFriendModalView = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section(
                    header:
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
                ) {
                    if friendManagement.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if let error = friendManagement.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if friendManagement.unifiedFriends.isEmpty {
                        Text("No friends yet")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(friendManagement.unifiedFriends) { unifiedFriend in
                            HStack {
                                Text(unifiedFriend.user.username)
                                    .font(.headline)
                                Spacer()

                                switch unifiedFriend.status {
                                case .confirmed:
                                    Button(action: {
                                        onMatchInitiated(unifiedFriend.user)
                                    }) {
                                        Text("Match ")
                                            .font(.bangers(size: 20))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.ishRed)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                            .shadow(
                                                color: .ishRed.opacity(0.3), radius: 4, x: 0,
                                                y: 2)
                                    }
                                case .pending:
                                    Button(action: {
                                        if let requestId = unifiedFriend.requestId {
                                            Task {
                                                try? await friendManagement.confirmFriendRequest(
                                                    requestId)
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
                                            .shadow(
                                                color: .ishBlue.opacity(0.3), radius: 4, x: 0,
                                                y: 2)
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
                            .background(Color.white)
                        }
                    }
                }
            }
        }
        .refreshable {
            Task {
                await friendManagement.fetchFriends()
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(20, corners: [.topLeft, .topRight])
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

// Add this extension to support rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect, byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
