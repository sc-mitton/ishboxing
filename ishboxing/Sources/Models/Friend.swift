import Foundation

public struct User: Identifiable {
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
