public struct Fight: Codable {
    public let from: String
    public let to: String
    public let id: String
}

public struct FightNotification: Codable {
    public let fight: Fight
}

public struct JoinedAck: Codable {
    public static let message = "joined"
}
