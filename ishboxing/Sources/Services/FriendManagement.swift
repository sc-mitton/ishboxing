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
    private var currentFetchTask: Task<Void, Never>?

    private init() {}

    func fetchFriends() async {
        // Cancel any existing fetch task
        currentFetchTask?.cancel()

        // Create new fetch task
        currentFetchTask = Task {
            await performFetch()
        }

        await currentFetchTask?.value
    }

    private func performFetch() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // Add timeout to prevent hanging
            let fetchTask = Task {
                try await supabaseService.getAllFriendRelationships()
            }

            let result = try await withTimeout(seconds: 10) {
                try await fetchTask.value
            }

            // Check if task was cancelled
            if Task.isCancelled {
                return
            }

            let (fetchedFriends, fetchedPendingRequests, fetchedSentRequests) = result

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

            await MainActor.run {
                friends = allFriends
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if error is CancellationError {
                    // Task was cancelled, don't show error
                    return
                }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T)
        async throws -> T
    {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
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

    // Method to reset loading state if it gets stuck
    func resetLoadingState() {
        currentFetchTask?.cancel()
        currentFetchTask = nil
        Task { @MainActor in
            isLoading = false
            errorMessage = nil
        }
    }

    // Debug method to check current state
    func debugState() {
        print("FriendManagement Debug State:")
        print("- isLoading: \(isLoading)")
        print("- errorMessage: \(errorMessage ?? "nil")")
        print("- friends count: \(friends.count)")
        print("- currentFetchTask: \(currentFetchTask != nil ? "active" : "nil")")
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

struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        return "Request timed out. Please try again."
    }
}
