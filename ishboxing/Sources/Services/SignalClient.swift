import Foundation
import Supabase
import WebRTC

protocol SignalClientDelegate: AnyObject {
    func signalClient(
        _ signalClient: SignalClient, didTimeout waitingForConnection: Bool)
    func signalClient(
        _ signalClient: SignalClient, didError error: Error)
    func signalClient(
        _ signalClient: SignalClient, didStateChange state: RTCIceConnectionState)
}

struct Response: Decodable {
    let status: Int
}

final class SignalClient {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let supabase: SupabaseService
    private let userId: String
    private let webRTCClient: WebRTCClient
    private let connectionTimeoutInterval: TimeInterval = 30  // 30 seconds timeout
    private var channelId: String = ""
    private var channel: RealtimeChannelV2!
    private var subscription: RealtimeSubscription!
    private var connectionTimeoutTimer: Timer?
    private var hasExchangedSDP: Bool = false  // Track SDP exchange status

    weak var delegate: SignalClientDelegate?

    init(supabase: SupabaseService, webRTCClient: WebRTCClient) {
        self.supabase = supabase
        let userId = supabase.client.auth.currentUser?.id.uuidString
        guard let userId = userId else {
            fatalError("User ID is nil")
        }
        self.userId = userId
        self.webRTCClient = webRTCClient
        self.webRTCClient.delegate = self
    }

    deinit {
        Task { [weak self] in
            guard let self = self else { return }
            await self.supabase.client.removeChannel(self.channel)
            self.subscription.cancel()
            self.connectionTimeoutTimer?.invalidate()
        }
    }

    func joinMatch(_ match: Match) async {
        self.channelId = match.id
        await self.openMatchSocketChannel(self.channelId)

        do {
            try await self.broadcastMessage(Message.joined(JoinedAck()))
        } catch {
            delegate?.signalClient(self, didError: error)
        }
    }

    func startMatch(with userId: String) async {
        self.channelId = UUID().uuidString
        let match = Match(
            from: User(id: UUID(uuidString: self.userId)!, username: ""),
            to: User(id: UUID(uuidString: userId)!, username: ""),
            id: self.channelId
        )
        await self.createMatch(match: match)
        await self.addChallengedUserToMatch(match: match)
        await self.openMatchSocketChannel(match.id)
        startConnectionTimeoutTimer()
    }

    func createMatch(match: Match) async {
        do {
            try await self.supabase.client.from("matches").insert(["topic": match.id]).execute()
        } catch {
            delegate?.signalClient(self, didError: error)
        }
    }

    func addChallengedUserToMatch(match: Match) async {
        do {
            try await self.supabase.client.from("match_users").insert([
                "match_topic": match.id,
                "profile_id": match.to.id.uuidString,
                "is_challenged": "true",
            ]).execute()
        } catch {
            delegate?.signalClient(self, didError: error)
        }
    }

    private func startConnectionTimeoutTimer() {
        // Cancel any existing timer
        connectionTimeoutTimer?.invalidate()

        // Create new timer
        connectionTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: connectionTimeoutInterval, repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            self.handleConnectionTimeout()
        }
    }

    private func handleConnectionTimeout() {
        delegate?.signalClient(self, didTimeout: true)
        closeConnection()
    }

    private func closeConnection() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        channelId = ""
        channel = nil
    }

    // MARK: - Socket Methods
    func openMatchSocketChannel(_ channelId: String) async {
        self.channel = self.supabase.client.channel(channelId) { config in
            config.isPrivate = true
        }
        self.subscription = self.channel.onBroadcast(event: "broadcast") { message in
            do {
                guard let payload = message["payload"] else {
                    return
                }
                let jsonData = try JSONSerialization.data(withJSONObject: payload.value)
                let decodedMessage = try self.decoder.decode(Message.self, from: jsonData)
                Task {
                    await self.handleBroadcastMessage(decodedMessage)
                }
            } catch {
                print("Error decoding message: \(message), error: \(error)")
            }
        }
        await self.channel.subscribe()
    }

    private func handleBroadcastMessage(_ message: Message) async {
        print("handleBroadcastMessage: \(String(describing: message).prefix(20))...")
        switch message {
        case .joined(_):
            webRTCClient.offer { [weak self] sdp in
                guard let self = self else { return }
                Task {
                    do {
                        print("user joined match, sending offer: \(sdp)")
                        try await self.broadcastMessage(
                            Message.sdp(SessionDescription(from: sdp))
                        )
                    } catch {
                        self.delegate?.signalClient(self, didError: error)
                    }
                }
            }
        case .candidate(let iceCandidate):
            print("setting remote candidate")
            webRTCClient.set(remoteCandidate: iceCandidate.rtcIceCandidate) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.signalClient(self, didError: error)
                }
            }
        case .sdp(let sdp):
            print("setting remote sdp")
            webRTCClient.set(remoteSdp: sdp.rtcSessionDescription) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.signalClient(self, didError: error)
                }
            }
            webRTCClient.answer { [weak self] sdp in
                guard let self = self else { return }
                Task {
                    do {
                        try await self.broadcastMessage(
                            Message.sdp(SessionDescription(from: sdp))
                        )
                    } catch {
                        self.delegate?.signalClient(self, didError: error)
                    }
                }
            }
            self.hasExchangedSDP = true
            print("hasExchangedSDP: \(self.hasExchangedSDP)")
        }
    }

    func broadcastMessage(_ message: Message) async throws {
        try await self.channel.broadcast(event: "broadcast", message: message)
    }
}

extension SignalClient: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    {
        Task {
            do {
                if hasExchangedSDP {
                    try await self.broadcastMessage(
                        Message.candidate(IceCandidate(from: candidate))
                    )
                } else {
                    print("Holding ICE candidate until SDP exchange is complete")
                }
            } catch {
                delegate?.signalClient(self, didError: error)
            }
        }
    }

    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    {
        delegate?.signalClient(self, didStateChange: state)
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        print("Received data: \(data)")
    }
}

enum SignalError: LocalizedError {
    case invalidServerURL
    case invalidResponse
    case serverError(statusCode: Int)
    case channelBroken

    var errorDescription: String? {
        switch self {
        case .channelBroken:
            return "Channel broken"
        case .invalidServerURL:
            return "Invalid server URL configuration"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        }
    }
}
