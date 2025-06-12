//
//  ishBoxingApp.swift
//  ish
//
//  Created by Spencer Mitton on 4/30/25.
//

import Foundation
import WebRTC

enum Message {
    case sdp(SessionDescription)
    case candidate(IceCandidate)
    case joined(JoinedAck)
}

extension Message: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case String(describing: RTCSessionDescription.self):
            self = .sdp(try container.decode(SessionDescription.self, forKey: .data))
        case String(describing: IceCandidate.self):
            self = .candidate(try container.decode(IceCandidate.self, forKey: .data))
        case "JoinedAck":
            self = .joined(JoinedAck())
        default:
            throw DecodeError.unknownType
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sdp(let sessionDescription):
            try container.encode(sessionDescription, forKey: .data)
            try container.encode(String(describing: RTCSessionDescription.self), forKey: .type)
        case .candidate(let iceCandidate):
            try container.encode(iceCandidate, forKey: .data)
            try container.encode(String(describing: IceCandidate.self), forKey: .type)
        case .joined(_):
            try container.encode([String: String](), forKey: .data)
            try container.encode("JoinedAck", forKey: .type)
        }
    }

    enum DecodeError: Error {
        case unknownType
    }

    enum CodingKeys: String, CodingKey {
        case type, data
    }
}
