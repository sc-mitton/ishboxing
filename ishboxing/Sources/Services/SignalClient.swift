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

final class SignalClient {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let supabase: SupabaseService
    private let userId: String
    private let webRTCClient: WebRTCClient
    private let connectionTimeoutInterval: TimeInterval = 30  // 30 seconds timeout
    private var channelId: String = ""
    private var channel: RealtimeChannelV2!
    private var connectionTimeoutTimer: Timer?

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

    func joinMeeting(_ meeting: Meeting) async {
        self.channelId = meeting.id
        await self.supabase.openSocketChannel(self.channelId)
        startConnectionTimeoutTimer()
    }

    func joinMeeting(with userId: String) async {
        self.channelId = UUID().uuidString
        let meeting = Meeting(from: self.userId, to: userId, id: self.channelId)
        await self.supabase.openSocketChannel(meeting.id)
        startConnectionTimeoutTimer()
        await notifyUser(meeting: meeting)
    }

    func notifyUser(meeting: Meeting) async {
        // Send initial meeting request via HTTP
        let meeting = Meeting(from: self.userId, to: userId, id: self.channelId)
        do {
            let data = try self.encoder.encode(meeting)
            guard
                let serverURLString = Bundle.main.object(forInfoDictionaryKey: "SERVER_URL")
                    as? String,
                let url = URL(string: serverURLString)
            else {
                throw SignalError.invalidServerURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SignalError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw SignalError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch {
            delegate?.signalClient(self, didError: error)
            return
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
}

extension SignalClient: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    {
        Task {
            do {
                try await self.supabase.broadcastMessage(
                    Message.candidate(IceCandidate(from: candidate))
                )
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

extension SignalClient: SupabaseServiceDelegate {
    func broadcasted(_ supabaseService: SupabaseService, didReceiveMessage message: Message) {
        switch message {
        case .joined(_):
            webRTCClient.offer { [weak self] sdp in
                guard let self = self else { return }
                Task {
                    do {
                        try await self.supabase.broadcastMessage(
                            Message.sdp(SessionDescription(from: sdp))
                        )
                    } catch {
                        self.delegate?.signalClient(self, didError: error)
                    }
                }
            }
        case .candidate(let iceCandidate):
            webRTCClient.set(remoteCandidate: iceCandidate.rtcIceCandidate) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.signalClient(self, didError: error)
                }
            }
        case .sdp(let sdp):
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
                        try await self.supabase.broadcastMessage(
                            Message.sdp(SessionDescription(from: sdp))
                        )
                    } catch {
                        self.delegate?.signalClient(self, didError: error)
                    }
                }
            }
        }
    }

    func broadcastChannelClosed(_ supabaseService: SupabaseService) {
        closeConnection()
        delegate?.signalClient(self, didError: SignalError.channelBroken)
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
