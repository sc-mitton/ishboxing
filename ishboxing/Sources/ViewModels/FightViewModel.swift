import Foundation
import WebRTC

protocol FightViewModelDelegate: AnyObject {
    func didConnect()
    func didDisconnect()
    func didTimeout()
    func didError(_ error: Error)
}

class FightViewModel: ObservableObject {
    private let friend: User
    private let signalClient: SignalClient
    private let fight: Fight?
    weak var delegate: FightViewModelDelegate?

    @Published var errorMessage: String?
    @Published var hasTimedOut = false
    @Published var webRTCConnectionState: RTCIceConnectionState?

    init(
        signalClient: SignalClient,
        friend: User,
        fight: Fight?
    ) {
        self.friend = friend
        self.signalClient = signalClient
        self.fight = fight
        self.signalClient.delegate = self

        Task {
            await connect()
        }
    }

    func connect() async {
        if let fight = fight {
            await signalClient.joinFight(fight)
        } else {
            await signalClient.startFight(with: friend.id.uuidString)
        }
    }
}

extension FightViewModel: SignalClientDelegate {
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
