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
    func signalClient(
        _ signalClient: SignalClient, didCreateMatch match: Match)
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
    private var queuedLocalCandidates: [RTCIceCandidate] = []
    private var queuedRemoteCandidates: [RTCIceCandidate] = []
    var workItem: DispatchWorkItem?

    weak var delegate: SignalClientDelegate?

    init(supabase: SupabaseService, webRTCClient: WebRTCClient) {
        self.supabase = supabase
        let userId = supabase.client.auth.currentUser?.id.uuidString
        guard let userId = userId else {
            fatalError("User ID is nil")
        }
        self.userId = userId
        self.webRTCClient = webRTCClient
        self.webRTCClient.signalingDelegate = self
    }

    deinit {
        Task { [weak self] in
            guard let self = self else { return }
            await self.supabase.client.removeChannel(self.channel)
            self.subscription.cancel()
            self.workItem?.cancel()
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

    func startMatch(with userId: String) async -> Match {
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
        return match
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
        debugPrint("Dispatching connection timeout timer")
        workItem = DispatchWorkItem {
            debugPrint("Timeout timer fired")
            self.handleConnectionTimeout()
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + connectionTimeoutInterval, execute: workItem!)
    }

    private func handleConnectionTimeout() {
        debugPrint("Handling connection timeout")
        delegate?.signalClient(self, didTimeout: true)
    }

    private func dismissConnectionTimeoutTimer() {
        workItem?.cancel()
        workItem = nil
    }

    func cleanUp() async {
        debugPrint("Cleaning up SignalClient")
        workItem?.cancel()
        workItem = nil
        channelId = ""
        channel = nil
        webRTCClient.close()
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
        debugPrint("handleBroadcastMessage: \(String(describing: message).prefix(20))...")
        switch message {
        case .joined(_):
            debugPrint("Received joined message, creating offer")

            dismissConnectionTimeoutTimer()

            webRTCClient.offer { [weak self] sdp in
                guard let self = self else { return }
                Task {
                    do {
                        debugPrint("Sending offer SDP")
                        try await self.broadcastMessage(
                            Message.sdp(SessionDescription(from: sdp))
                        )
                    } catch {
                        self.delegate?.signalClient(self, didError: error)
                    }
                }
            }
        case .candidate(let iceCandidate):
            debugPrint("Received ICE candidate: \(iceCandidate.sdp)")
            if !webRTCClient.hasExchangedSDP {
                debugPrint("Queuing remote candidate")
                queuedRemoteCandidates.append(iceCandidate.rtcIceCandidate)
            } else {
                webRTCClient.set(remoteCandidate: iceCandidate.rtcIceCandidate) {
                    [weak self] error in
                    guard let self = self else { return }
                    if let error = error {
                        debugPrint("Error setting remote candidate: \(error)")
                        self.delegate?.signalClient(self, didError: error)
                    } else {
                        debugPrint("Successfully set remote candidate")
                    }
                }
            }
        case .sdp(let sdp):
            debugPrint("Received SDP of type: \(sdp.type)")
            debugPrint("Setting remote SDP")
            webRTCClient.set(remoteSdp: sdp.rtcSessionDescription) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    debugPrint("Error setting remote SDP: \(error)")
                    self.delegate?.signalClient(self, didError: error)
                }
            }

            if sdp.type == .offer {
                debugPrint("Creating answer SDP")
                webRTCClient.answer { [weak self] sdp in
                    guard let self = self else { return }
                    Task {
                        do {
                            debugPrint("Sending answer SDP")
                            try await self.broadcastMessage(
                                Message.sdp(SessionDescription(from: sdp))
                            )
                        } catch {
                            self.delegate?.signalClient(self, didError: error)
                        }
                    }
                }
            }
        }
    }

    func flushQueuedCandidates() {
        debugPrint("flushing queued local candidates of count: \(queuedLocalCandidates.count)")
        for candidate in queuedLocalCandidates {
            Task {
                try? await self.broadcastMessage(Message.candidate(IceCandidate(from: candidate)))
            }
        }
        queuedLocalCandidates.removeAll()
    }

    func flushQueuedRemoteCandidates() {
        debugPrint("flushing queued remote candidates of count: \(queuedRemoteCandidates.count)")
        for candidate in queuedRemoteCandidates {
            webRTCClient.set(remoteCandidate: candidate) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.signalClient(self, didError: error)
                }
            }
        }
        queuedRemoteCandidates.removeAll()
    }

    func broadcastMessage(_ message: Message) async throws {
        try await self.channel.broadcast(event: "broadcast", message: message)
    }
}

extension SignalClient: WebRTCClientSignalingDelegate {
    func webRTCClient(_ client: WebRTCClient, didGenerate candidate: RTCIceCandidate) {
        debugPrint("didGenerate candidate, queuedLocalCandidates: \(queuedLocalCandidates.count)")
        if !webRTCClient.hasExchangedSDP {
            queuedLocalCandidates.append(candidate)
        } else {
            Task {
                try? await self.broadcastMessage(Message.candidate(IceCandidate(from: candidate)))
            }
        }
    }

    func webRTCClient(_ client: WebRTCClient, didChangeSignalingState state: RTCSignalingState) {
        self.flushQueuedCandidates()
        self.flushQueuedRemoteCandidates()
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
