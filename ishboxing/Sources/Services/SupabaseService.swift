import Foundation
import Supabase

struct ProfileResponse: Codable {
    let id: String
    let username: String?
}

struct UsernameResponse: Codable {
    let username: String?
}

struct MatchResultResponse: Codable {
    let winner: String
    let loser: String
    let created_at: String
}

class SupabaseService: ObservableObject {
    public let client: SupabaseClient
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    static let shared = SupabaseService()
    static let serverURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
    @Published var isAuthenticated = false

    public func getUser() async -> User? {
        do {
            let session = try await client.auth.session
            return User(
                id: session.user.id,
                username: session.user.userMetadata["username"]?.stringValue ?? "")
        } catch {
            return nil
        }
    }

    init() {
        guard let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY")
                as? String
        else {
            fatalError("Supabase configuration not found in Info.plist")
        }
        let updatedSupabaseURL = supabaseURL.replacingOccurrences(of: "#", with: "/")

        self.client = SupabaseClient(
            supabaseURL: URL(string: updatedSupabaseURL)!,
            supabaseKey: supabaseKey
        )
        // Check initial auth state
        Task {
            let session = try? await client.auth.session
            await MainActor.run {
                self.isAuthenticated = session != nil
            }
        }
    }

    func hasSession() async throws -> Bool {
        let session = try await client.auth.session
        return session != nil
    }

    func addChannelAccess(_ channelId: String, owner: String, members: [String]) async throws {
        try await client.from("meeting_users")
            .upsert(
                ["meeting_topic": channelId, "profile_id": owner, "is_owner": "true"],
                onConflict: "meeting_topic,profile_id"
            )
            .execute()
        for member in members {
            try await client.from("meeting_users").insert([
                "meeting_topic": channelId, "profile_id": member, "is_owner": "false",
            ]).execute()
        }
    }

    func cleanupChannelAccess(_ channelId: String) async throws {
        try await client.from("meeting_users")
            .delete()
            .eq("meeting_topic", value: channelId)
            .execute()
        try await client.from("meetings")
            .delete()
            .eq("id", value: channelId)
            .execute()
    }

    func signInWithPhoneNumber(_ phoneNumber: String) async throws {
        try await client.auth.signInWithOTP(
            phone: phoneNumber
        )
    }

    func verifyOTP(phoneNumber: String, token: String) async throws {
        try await client.auth.verifyOTP(
            phone: phoneNumber,
            token: token,
            type: .sms
        )
    }

    func hasUsername() async throws -> Bool {
        do {
            let session = try await client.auth.session
            let userId = session.user.id
            let response = try await client.from("profiles").select("username").eq(
                "id", value: userId
            )
            .single().execute()

            do {
                let profile = try decoder.decode(UsernameResponse.self, from: response.data)
                return profile.username != nil
            } catch {
                debugPrint("Failed to decode profile: \(error)")
                throw error
            }
        } catch {
            debugPrint("Error in hasUsername: \(error)")
            throw error
        }
    }

    func updateUsername(_ username: String) async throws {
        try await client.auth.update(
            user: UserAttributes(data: ["username": .string(username)])
        )
    }

    func hasMatchWaiting() async throws -> Bool {
        let session = try await client.auth.session
        let userId = session.user.id
        let response = try await client.from("matches")
            .select("id")
            .eq("user_id", value: userId)
            .eq("status", value: "pending")
            .execute()

        return response.data.count > 0
    }

    func getAllFriendRelationships() async throws -> (
        confirmedFriends: [User], pendingRequests: [FriendRequest], sentRequests: [FriendRequest]
    ) {
        let session = try await client.auth.session
        let userId = session.user.id

        do {
            // Single query to get all friend relationships where current user is involved
            let response = try await client.from("friends")
                .select(
                    """
                        id,
                        user_id,
                        friend_id,
                        confirmed,
                        friend_profile:profiles!friends_friend_id_fkey (
                            username
                        ),
                        user_profile:profiles!friends_user_id_fkey (
                            username
                        )
                    """
                )
                .or("user_id.eq.\(userId),friend_id.eq.\(userId)")
                .execute()

            // Parse the response
            let relationshipsData = try self.decoder.decode(
                [FriendRelationshipResponse].self, from: response.data)

            var confirmedFriends: [User] = []
            var pendingRequests: [FriendRequest] = []
            var sentRequests: [FriendRequest] = []

            for relationship in relationshipsData {
                if relationship.confirmed == true {
                    // This is a confirmed friendship
                    let friendUser: User
                    if relationship.user_id == userId {
                        // Current user is user_id, so use friend's info
                        friendUser = User(
                            id: relationship.friend_id,
                            username: relationship.friend_profile.username
                        )
                    } else {
                        // Current user is friend_id, so use user's info
                        friendUser = User(
                            id: relationship.user_id,
                            username: relationship.user_profile.username
                        )
                    }
                    confirmedFriends.append(friendUser)
                } else {
                    // This is a pending request
                    if relationship.user_id == userId {
                        // Current user sent the request
                        let sentRequest = FriendRequest(
                            id: relationship.id,
                            from: relationship.user_id,
                            to: relationship.friend_id,
                            username: relationship.friend_profile.username
                        )
                        sentRequests.append(sentRequest)
                    } else {
                        // Current user received the request
                        let pendingRequest = FriendRequest(
                            id: relationship.id,
                            from: relationship.user_id,
                            to: relationship.friend_id,
                            username: relationship.user_profile.username
                        )
                        pendingRequests.append(pendingRequest)
                    }
                }
            }

            return (confirmedFriends, pendingRequests, sentRequests)
        } catch let decodingError as DecodingError {
            debugPrint("Decoding error in getAllFriendRelationships: \(decodingError)")
            throw NSError(
                domain: "SupabaseService",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to parse friend data. Please try again."
                ]
            )
        } catch {
            debugPrint("Error in getAllFriendRelationships: \(error)")
            throw error
        }
    }

    func addFriend(_ username: String) async throws {
        let session = try await client.auth.session
        let userId = session.user.id

        // Get the friend's profile first
        let response = try await client.from("profiles")
            .select("id")
            .eq("username", value: username)
            .single()
            .execute()

        // Check if friend exists
        guard let friendData = try? self.decoder.decode(ProfileResponse.self, from: response.data)
        else {
            throw NSError(
                domain: "", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user found with username: \(username)"])
        }

        // Insert friend relationship
        try await client.from("friends").insert(
            [
                "user_id": userId.uuidString,
                "friend_id": friendData.id,
            ]
        ).execute()
    }

    func confirmFriendship(_ friendshipId: String) async throws {
        try await client.from("friends")
            .update(["confirmed": true])
            .eq("id", value: friendshipId)
            .execute()
    }

    func deleteFriendship(_ friendshipId: String) async throws {
        debugPrint("Deleting friendship: \(friendshipId)")
        try await client.from("friends")
            .delete()
            .or("friend_id.eq.\(friendshipId),user_id.eq.\(friendshipId)")
            .execute()
    }

    func denyFriendship(_ friendshipId: String) async throws {
        try await deleteFriendship(friendshipId)
    }

    func saveAPNToken(token: String, deviceId: String) async throws {
        let session = try await client.auth.session
        let userId = session.user.id

        debugPrint("Saving APN token: \(token) for device: \(deviceId)")

        try await client
            .from("apn_tokens")
            .upsert(
                [
                    "profile_id": userId.uuidString,
                    "token": token,
                    "device_id": deviceId,
                ], onConflict: "profile_id"
            )
            .execute()
    }

    func getMatchStats() async throws -> (wins: Int, losses: Int, streak: Int) {
        let session = try await client.auth.session
        let userId = session.user.id
        let response = try await client.from("match_results")
            .select("winner, loser, created_at")
            .or("winner.eq.\(userId),loser.eq.\(userId)")
            .order("created_at", ascending: true)
            .execute()

        let matches = try self.decoder.decode([MatchResultResponse].self, from: response.data)

        var streak = 0
        var wins = 0
        var losses = 0

        for match in matches {
            if match.winner == userId.uuidString {
                streak += 1
            } else {
                break
            }
        }

        for match in matches {
            if match.winner == userId.uuidString {
                wins += 1
            } else {
                losses += 1
            }
        }
        return (wins, losses, streak)
    }
}

protocol SupabaseServiceDelegate: AnyObject {
    func broadcasted(_ supabaseService: SupabaseService, didReceiveMessage message: Message) async
    func broadcastChannelClosed(_ supabaseService: SupabaseService)
}
