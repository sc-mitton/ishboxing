import Foundation

public struct Match: Identifiable, Codable {
    public let from: User
    public let to: User
    public let id: String
}

public struct MatchNotificationPayload: Codable {
    public struct UserData: Codable {
        public let id: String
        public let username: String
    }

    public let id: String
    public let from: UserData
    public let to: UserData

    public func toMatch() -> Match {
        Match(
            from: User(id: UUID(uuidString: from.id)!, username: from.username),
            to: User(id: UUID(uuidString: to.id)!, username: to.username),
            id: id
        )
    }
}

public struct MatchNotification: Codable {
    public let match: Match
}

public struct JoinedAck: Codable {
    public static let message = "joined"
    public init() {}
}
