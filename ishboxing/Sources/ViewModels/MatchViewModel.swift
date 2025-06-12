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
    @Published var hasTimedOut = false
    @Published var webRTCConnectionState: RTCIceConnectionState?
    @Published var isMuted = false
    @Published var showTimeoutAlert = false

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
    func signalClient(_ signalClient: SignalClient, didStateChange state: RTCIceConnectionState) {
        debugPrint("didIceConnectionStateChange: \(state)")
    }

    func signalClient(_ signalClient: SignalClient, didTimeout waitingForConnection: Bool) {
        debugPrint("didTimeout: \(waitingForConnection)")
        showTimeoutAlert = true
    }

    func signalClient(_ signalClient: SignalClient, didError error: Error) {
        debugPrint("didError: \(error)")
    }

    func signalClient(_ signalClient: SignalClient, didCreateMatch match: Match) {
        debugPrint("didCreateMatch: \(match)")
        gameEngine.setMatch(match: match)
    }
}

extension MatchViewModel: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    {
        debugPrint("didChangeConnectionState: \(state)")
        DispatchQueue.main.async {
            self.webRTCConnectionState = state
        }
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        debugPrint("didReceiveData: \(data)")
    }
}
