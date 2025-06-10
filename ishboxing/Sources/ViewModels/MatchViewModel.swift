import Foundation
import WebRTC

protocol MatchViewModelDelegate: AnyObject {
    func didConnect()
    func didDisconnect()
    func didTimeout()
    func didError(_ error: Error)
}

class MatchViewModel: ObservableObject {
    private let friend: User
    private let signalClient: SignalClient
    private let webRTCClient: WebRTCClient
    private let match: Match?
    weak var delegate: MatchViewModelDelegate?

    @Published var errorMessage: String?
    @Published var hasTimedOut = false
    @Published var webRTCConnectionState: RTCIceConnectionState?

    init(
        signalClient: SignalClient,
        webRTCClient: WebRTCClient,
        friend: User,
        match: Match?
    ) {
        self.friend = friend
        self.signalClient = signalClient
        self.match = match
        self.webRTCClient = webRTCClient
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
    }

    func unmuteAudio() {
        webRTCClient.unmuteAudio()
    }
}

extension MatchViewModel: SignalClientDelegate {
    func signalClient(_ signalClient: SignalClient, didStateChange state: RTCIceConnectionState) {
        webRTCConnectionState = state
    }

    func signalClient(_ signalClient: SignalClient, didTimeout waitingForConnection: Bool) {
        print("didTimeout: \(waitingForConnection)")
    }

    func signalClient(_ signalClient: SignalClient, didError error: Error) {
        print("didError: \(error)")
    }
}
