import Foundation
import Supabase

class SupabaseService: ObservableObject {
    public let client: SupabaseClient
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var channel: RealtimeChannelV2!
    weak var delegate: SupabaseServiceDelegate?
    static let shared = SupabaseService()
    @Published var isAuthenticated = false

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

        // Set up auth state change listener
        Task {
            for await (_, session) in client.auth.authStateChanges {
                await MainActor.run {
                    self.isAuthenticated = session != nil
                }
            }
        }
    }

    func hasSession() async throws -> Bool {
        let session = try await client.auth.session
        return session != nil
    }

    func openSocketChannel(_ channelId: String) async {
        self.channel = self.client.channel(channelId) { config in
            config.isPrivate = true
        }
        await self.listenForBroadcastMessages()
    }

    private func listenForBroadcastMessages() async {
        let broadcastStream = self.channel.broadcastStream(event: "broadcast")
        await self.channel.subscribe()
        for await broadcastMessage in broadcastStream {
            let message: Message

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: broadcastMessage)
                message = try decoder.decode(Message.self, from: jsonData)
            } catch {
                print("Error decoding message: \(error)")
                return
            }
            await self.delegate?.broadcasted(self, didReceiveMessage: message)
        }
    }

    func broadcastMessage(_ message: Message) async throws {
        try await self.channel.broadcast(event: "broadcast", message: message)
    }

    func addChannelAccess(_ channelId: String, owner: String, members: [String]) async throws {
        try await client.from("meeting_users")
            .upsert(
                ["meeting_topic": channelId, "user_id": owner, "is_owner": "true"],
                onConflict: "meeting_topic,user_id"
            )
            .execute()
        for member in members {
            try await client.from("meeting_users").insert([
                "meeting_topic": channelId, "user_id": member, "is_owner": "false",
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

    func updateUsername(_ username: String) async throws {
        let session = try await client.auth.session
        let userId = session.user.id
        try await client.from("profiles")
            .update(["username": username])
            .eq("id", value: userId)
            .execute()
    }

    func getFriends() async throws -> [User] {
        let session = try await client.auth.session
        let userId = session.user.id

        // Fetch friends where the current user is either user_id or friend_id
        let response =
            try await client
            .from("friends")
            .select("friend_id, profiles:friend_id(username)")
            .eq("user_id", value: userId)
            .execute()

        // Parse the response and create Friend objects
        let friendsData = try JSONDecoder().decode([FriendResponse].self, from: response.data)
        return friendsData.map { response in
            User(
                id: response.id,
                username: response.friend.username
            )
        }
    }
}

protocol SupabaseServiceDelegate: AnyObject {
    func broadcasted(_ supabaseService: SupabaseService, didReceiveMessage message: Message) async
    func broadcastChannelClosed(_ supabaseService: SupabaseService)
}
