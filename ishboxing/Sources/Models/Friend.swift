import Foundation

public struct User: Identifiable, Codable {
    public let id: UUID
    public let username: String

    public init(id: UUID, username: String) {
        self.id = id
        self.username = username
    }
}

public struct FriendUser: Codable {
    public let username: String

    public init(username: String) {
        self.username = username
    }
}

public struct FriendRequest: Codable {
    public let id: UUID
    public let user_id: UUID
    public let friend_id: UUID
    public let friend: FriendUser

    public init(id: UUID, from: UUID, to: UUID, username: String) {
        self.id = id
        self.user_id = from
        self.friend_id = to
        self.friend = FriendUser(username: username)
    }
}

// Response structure for all friend relationships
public struct FriendRelationshipResponse: Codable {
    public let id: UUID
    public let user_id: UUID
    public let friend_id: UUID
    public let confirmed: Bool?
    public let friend_profile: FriendUser
    public let user_profile: FriendUser

    public init(
        id: UUID, user_id: UUID, friend_id: UUID, confirmed: Bool?, friend_profile: FriendUser,
        user_profile: FriendUser
    ) {
        self.id = id
        self.user_id = user_id
        self.friend_id = friend_id
        self.confirmed = confirmed
        self.friend_profile = friend_profile
        self.user_profile = user_profile
    }
}
