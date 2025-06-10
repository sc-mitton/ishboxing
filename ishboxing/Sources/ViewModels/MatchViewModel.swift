import Foundation
import WebRTC

protocol MatchViewModelDelegate: AnyObject {
    func didDisconnect()
}

class MatchViewModel: ObservableObject {
    private let friend: User
    private let signalClient: SignalClient
    private let webRTCClient: WebRTCClient
    private let match: Match?
    private let onDismiss: () -> Void
    weak var matchViewModelDelegate: MatchViewModelDelegate?

    @Published var errorMessage: String?
    @Published var hasTimedOut = false
    @Published var webRTCConnectionState: RTCIceConnectionState?
    @Published var isMuted = false
    @Published var showTimeoutAlert = false

    init(
        signalClient: SignalClient,
        webRTCClient: WebRTCClient,
        friend: User,
        match: Match?,
        onDismiss: @escaping () -> Void
    ) {
        self.friend = friend
        self.signalClient = signalClient
        self.match = match
        self.webRTCClient = webRTCClient
        self.onDismiss = onDismiss
        self.signalClient.delegate = self
        Task {
            await connect()
        }
    }

    func connect() async {
        if let match = match {
            await signalClient.joinMatch(match)
        } else {
            await signalClient.startMatch(with: friend.id.uuidString)
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
        matchViewModelDelegate?.didDisconnect()
        onDismiss()
        Task {
            await signalClient.cleanUp()
        }
    }
}

extension MatchViewModel: SignalClientDelegate {
    func signalClient(_ signalClient: SignalClient, didStateChange state: RTCIceConnectionState) {
        webRTCConnectionState = state
    }

    func signalClient(_ signalClient: SignalClient, didTimeout waitingForConnection: Bool) {
        debugPrint("didTimeout: \(waitingForConnection)")
        showTimeoutAlert = true
    }

    func signalClient(_ signalClient: SignalClient, didError error: Error) {
        debugPrint("didError: \(error)")
    }
}
