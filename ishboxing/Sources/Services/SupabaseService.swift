import Foundation
import Supabase

struct ProfileResponse: Codable {
    let id: String
    let username: String?
}

struct UsernameResponse: Codable {
    let username: String?
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

    func getFriends() async throws -> [User] {
        let session = try await client.auth.session
        let userId = session.user.id

        // Fetch friends where the current user is either user_id or friend_id
        let response = try await client.from("friends")
            .select(
                """
                    id,
                    user_id,
                    friend_id,
                    friend:profiles!friends_friend_id_fkey (
                        username
                    ),
                    user:profiles!friends_user_id_fkey (
                        username
                    )
                """
            )
            .or("user_id.eq.\(userId),friend_id.eq.\(userId)")
            .eq("confirmed", value: true)
            .execute()

        // Parse the response and create Friend objects
        let friendsData = try self.decoder.decode([FriendResponse].self, from: response.data)

        return friendsData.map { response in
            if response.user_id == session.user.id {
                // Current user is user_id, so use friend's info
                User(
                    id: response.friend_id,
                    username: response.friend.username
                )
            } else {
                // Current user is friend_id, so use user's info
                User(
                    id: response.user_id,
                    username: response.user.username
                )
            }
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

    func getPendingFriendRequests() async throws -> [FriendRequest] {
        let session = try await client.auth.session
        let userId = session.user.id
        let response = try await client.from("friends")
            .select("id, user_id, friend_id, profiles:user_id(username)")
            .eq("friend_id", value: userId)
            .or("confirmed.eq.false,confirmed.is.null")
            .execute()

        // Parse the response and create FriendRequest objects
        let friendsData = try self.decoder.decode([FriendRequestResponse].self, from: response.data)
        return friendsData.map { response in
            FriendRequest(
                id: response.id,
                from: response.user_id,
                to: response.friend_id,
                username: response.profiles.username
            )
        }
    }

    func getPendingSentFriendRequests() async throws -> [FriendRequest] {
        let session = try await client.auth.session
        let userId = session.user.id
        let response = try await client.from("friends")
            .select("id, user_id, friend_id, profiles:friend_id(username)")
            .eq("user_id", value: userId)
            .or("confirmed.eq.false,confirmed.is.null")
            .execute()

        let friendsData = try self.decoder.decode([FriendRequestResponse].self, from: response.data)
        return friendsData.map { response in
            FriendRequest(
                id: response.id,
                from: response.user_id,
                to: response.friend_id,
                username: response.profiles.username
            )
        }
    }

    func saveAPNToken(token: String, deviceId: String) async throws {
        let session = try await client.auth.session
        let userId = session.user.id

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
}

protocol SupabaseServiceDelegate: AnyObject {
    func broadcasted(_ supabaseService: SupabaseService, didReceiveMessage message: Message) async
    func broadcastChannelClosed(_ supabaseService: SupabaseService)
}
