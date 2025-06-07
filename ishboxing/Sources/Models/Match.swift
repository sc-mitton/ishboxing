public struct Match: Identifiable, Codable {
    public let from: User
    public let to: User
    public let id: String
}

public struct MatchNotification: Codable {
    public let match: Match
}

public struct JoinedAck: Codable {
    public static let message = "joined"
}
