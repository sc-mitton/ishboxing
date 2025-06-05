//
//  ishBoxingApp.swift
//  ish
//
//  Created by Spencer Mitton on 4/30/25.
//

import Foundation

// We use Google's public stun servers. For production apps you should deploy your own stun/turn servers.
private let defaultIceServers = [
    "stun:stun.l.google.com:19302",
    "stun:stun.l.google.com:5349",
    "stun:stun1.l.google.com:3478",
    "stun:stun1.l.google.com:5349",
    "stun:stun2.l.google.com:19302",
    "stun:stun2.l.google.com:5349",
    "stun:stun3.l.google.com:3478",
    "stun:stun3.l.google.com:5349",
    "stun:stun4.l.google.com:19302",
    "stun:stun4.l.google.com:5349",
]

struct WebRTCConfig {
    let iceServers: [String]

    static let `default` = WebRTCConfig(
        iceServers: defaultIceServers)
}
