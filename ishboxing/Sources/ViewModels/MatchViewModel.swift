import Foundation
import WebRTC

class MatchViewModel: ObservableObject {
    private let friend: User
    private let signalClient: SignalClient
    private let webRTCClient: WebRTCClient
    private let onDismiss: () -> Void
    private var match: Match?
    public var gameEngine: GameEngine!

    @Published var errorMessage: String?
    @Published var hasTimedOut: Bool = false
    @Published var isMuted = false
    @Published var showTimeoutAlert = false
    @Published var webRTCSignalingState: RTCSignalingState?
    @Published var webRTCConnectionState: RTCIceConnectionState?

    init(
        signalClient: SignalClient,
        webRTCClient: WebRTCClient,
        gameEngine: GameEngine,
        friend: User,
        match: Match?,
        onDismiss: @escaping () -> Void,
    ) {
        self.friend = friend
        self.signalClient = signalClient
        self.match = match
        self.webRTCClient = webRTCClient
        self.onDismiss = onDismiss
        self.gameEngine = gameEngine
        self.signalClient.delegate = self
        self.webRTCClient.delegate = self

        Task {
            await connect()
        }
    }

    func connect() async {
        if let match = match {
            await signalClient.joinMatch(match)
        } else {
            let match = await signalClient.startMatch(with: friend.id.uuidString)
            self.match = match
        }
    }

    func muteAudio() {
        webRTCClient.muteAudio()
        isMuted = true
    }

    func unmuteAudio() {
        webRTCClient.unmuteAudio()
        isMuted = false
    }

    func endMatch() {
        webRTCClient.close()
        onDismiss()
        Task {
            await signalClient.cleanUp()
        }
    }
}

extension MatchViewModel: SignalClientDelegate {
    func signalClient(
        _ signalClient: SignalClient, didSignalingStateChange state: RTCSignalingState
    ) {
        debugPrint("didSignalingStateChange: \(state)")
        DispatchQueue.main.async {
            self.webRTCSignalingState = state
        }
    }

    func signalClient(_ signalClient: SignalClient, didTimeout waitingForConnection: Bool) {
        debugPrint("didTimeout: \(waitingForConnection)")
        showTimeoutAlert = true
    }

    func signalClient(_ signalClient: SignalClient, didError error: Error) {
        debugPrint("didError: \(error)")
    }

    func signalClient(_ signalClient: SignalClient, didCreateMatch match: Match) {
        gameEngine.setMatch(match: match)
    }
}

extension MatchViewModel: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didChangeDataChannelState state: RTCDataChannelState)
    {
        debugPrint("didChangeDataChannelState: \(state)")
        if state == .open {
            gameEngine.start()
        }
    }

    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    {
        debugPrint("didChangeConnectionState: \(state)")
        DispatchQueue.main.async {
            self.webRTCConnectionState = state
        }
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        do {
            let payload = try JSONDecoder().decode(RTCDataPayload.self, from: data)
            switch payload.type {
            case "swipePoint":
                if payload.data.isEmpty {
                    DispatchQueue.main.async {
                        self.gameEngine.remoteSwipe(point: nil)
                    }
                } else {
                    let pointDict = try JSONDecoder().decode(
                        [String: Double].self, from: payload.data)
                    let point = CGPoint(x: pointDict["x"] ?? 0, y: pointDict["y"] ?? 0)
                    DispatchQueue.main.async {
                        self.gameEngine.remoteSwipe(point: point)
                    }
                }
            case "ready":
                DispatchQueue.main.async {
                    self.gameEngine.oponentIsReady = true
                }
            case "punchConnected":
                DispatchQueue.main.async {
                    self.gameEngine.onRemotePunchConnected()
                }
            case "punchDodged":
                DispatchQueue.main.async {
                    self.gameEngine.onRemotePunchDodged()
                }
            case "screenSize":
                let screenSizeDict = try JSONDecoder().decode(
                    [String: Double].self, from: payload.data)
                let screenSize = CGSize(
                    width: screenSizeDict["width"] ?? 0,
                    height: screenSizeDict["height"] ?? 0,
                )
                DispatchQueue.main.async {
                    self.gameEngine.oponentScreenRatio = CGSize(
                        width: UIScreen.main.bounds.width / screenSize.width,
                        height: UIScreen.main.bounds.height / screenSize.height
                    )
                }
            default:
                break
            }
        } catch {
            debugPrint("Error decoding data: \(error)")
        }
    }
}
