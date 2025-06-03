public struct Meeting: Codable {
    public let from: String
    public let to: String
    public let id: String
}

public struct MeetingNotification: Codable {
    public let meeting: Meeting
}

public struct JoinedAck: Codable {
    public static let message = "joined"
}
