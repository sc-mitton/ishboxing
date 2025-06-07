import Foundation

public struct User: Identifiable, Codable {
    public let id: UUID
    public let username: String

    public init(id: UUID, username: String) {
        self.id = id
        self.username = username
    }
}

public struct FriendResponse: Codable {
    public let id: UUID
    public let friend: FriendUser

    public init(id: UUID, friend: FriendUser) {
        self.id = id
        self.friend = friend
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

public struct FriendRequestResponse: Codable {
    public let id: UUID
    public let user_id: UUID
    public let friend_id: UUID
    public let profiles: FriendUser
}
