public struct Match: Codable {
    public let from: String
    public let to: String
    public let id: String
}

public struct MatchNotification: Codable {
    public let match: Match
}

public struct JoinedAck: Codable {
    public static let message = "joined"
}
