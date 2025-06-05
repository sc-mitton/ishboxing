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
            self = .sdp(try container.decode(SessionDescription.self, forKey: .payload))
        case String(describing: IceCandidate.self):
            self = .candidate(try container.decode(IceCandidate.self, forKey: .payload))
        default:
            throw DecodeError.unknownType
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sdp(let sessionDescription):
            try container.encode(sessionDescription, forKey: .payload)
            try container.encode(String(describing: SessionDescription.self), forKey: .type)
        case .candidate(let iceCandidate):
            try container.encode(iceCandidate, forKey: .payload)
            try container.encode(String(describing: IceCandidate.self), forKey: .type)
        case .joined(let joinedAck):
            try container.encode(joinedAck, forKey: .payload)
            try container.encode(String(describing: JoinedAck.self), forKey: .type)
        }
    }

    enum DecodeError: Error {
        case unknownType
    }

    enum CodingKeys: String, CodingKey {
        case type, payload
    }
}
