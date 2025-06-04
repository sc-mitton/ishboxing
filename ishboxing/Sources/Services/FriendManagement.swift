import SwiftUI

class FriendManagement: ObservableObject {
    @Published var friends: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabaseService = SupabaseService.shared

    func fetchFriends() async {
        isLoading = true
        errorMessage = nil

        do {
            friends = try await supabaseService.getFriends()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func addFriend(_ username: String) async throws {
        guard !username.isEmpty else {
            throw FriendError.emptyUsername
        }

        try await supabaseService.addFriend(username)
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
