import SwiftUI

enum FriendStatus {
    case confirmed
    case pending
    case requested
}

struct FriendItem: Identifiable {
    let id: UUID
    let user: User
    let status: FriendStatus
    let requestId: UUID?
}

class FriendManagement: ObservableObject {
    static let shared = FriendManagement()

    @Published var friends: [FriendItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabaseService = SupabaseService.shared

    private init() {}

    func fetchFriends() async {
        isLoading = true
        errorMessage = nil

        do {
            let (fetchedFriends, fetchedPendingRequests, fetchedSentRequests) =
                try await supabaseService.getAllFriendRelationships()

            // Create list with unique IDs
            var allFriends: [FriendItem] = []

            // Add confirmed friends
            allFriends.append(
                contentsOf: fetchedFriends.map { friend in
                    FriendItem(
                        id: UUID(),
                        user: friend,
                        status: .confirmed,
                        requestId: nil
                    )
                })

            // Add pending friend requests (received by current user)
            allFriends.append(
                contentsOf: fetchedPendingRequests.map { request in
                    FriendItem(
                        id: UUID(),
                        user: User(id: request.user_id, username: request.friend.username),
                        status: .pending,
                        requestId: request.id
                    )
                })

            // Add sent friend requests (sent by current user)
            allFriends.append(
                contentsOf: fetchedSentRequests.map { request in
                    FriendItem(
                        id: UUID(),
                        user: User(id: request.friend_id, username: request.friend.username),
                        status: .requested,
                        requestId: request.id
                    )
                })

            friends = allFriends
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func addFriend(_ username: String) async throws {
        guard !username.isEmpty else {
            throw FriendError.emptyUsername
        }
        try await supabaseService.addFriend(username)
        await fetchFriends()  // Refresh the friends list
    }

    func confirmFriendRequest(_ requestId: UUID) async throws {
        try await supabaseService.confirmFriendship(requestId.uuidString)
        await fetchFriends()  // Refresh the friends list
    }

    func denyFriendRequest(_ requestId: UUID) async throws {
        try await supabaseService.denyFriendship(requestId.uuidString)
        await fetchFriends()  // Refresh the friends list
    }

    func deleteFriend(_ friendId: UUID) async throws {
        try await supabaseService.deleteFriendship(friendId.uuidString)
        await fetchFriends()  // Refresh the friends list
    }
}

enum FriendError: LocalizedError {
    case emptyUsername

    var errorDescription: String? {
        switch self {
        case .emptyUsername:
            return "Please enter a username"
        }
    }
}
