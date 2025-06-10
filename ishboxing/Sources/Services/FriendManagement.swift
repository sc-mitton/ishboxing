import SwiftUI

enum FriendStatus {
    case confirmed
    case pending
    case requested
}

struct UnifiedFriend: Identifiable {
    let id: UUID
    let user: User
    let status: FriendStatus
    let requestId: UUID?
}

class FriendManagement: ObservableObject {
    static let shared = FriendManagement()

    @Published var unifiedFriends: [UnifiedFriend] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabaseService = SupabaseService.shared

    private init() {}

    func fetchFriends() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedFriends = try await supabaseService.getFriends()
            let fetchedPendingRequests = try await supabaseService.getPendingFriendRequests()
            let fetchedSentRequests = try await supabaseService.getPendingSentFriendRequests()

            // Create unified list with unique IDs
            var unified: [UnifiedFriend] = []

            // Add confirmed friends
            unified.append(
                contentsOf: fetchedFriends.map { friend in
                    UnifiedFriend(
                        id: UUID(),
                        user: friend,
                        status: .confirmed,
                        requestId: nil
                    )
                })

            // Add pending friend requests
            unified.append(
                contentsOf: fetchedPendingRequests.map { request in
                    UnifiedFriend(
                        id: UUID(),
                        user: User(id: request.friend_id, username: request.friend.username),
                        status: .pending,
                        requestId: request.id
                    )
                })

            // Add sent friend requests
            unified.append(
                contentsOf: fetchedSentRequests.map { request in
                    UnifiedFriend(
                        id: UUID(),
                        user: User(id: request.friend_id, username: request.friend.username),
                        status: .requested,
                        requestId: request.id
                    )
                })

            unifiedFriends = unified
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
