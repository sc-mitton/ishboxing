import Foundation
import WebRTC

protocol FightInitiationViewModelDelegate: AnyObject {
    func didConnect()
    func didDisconnect()
    func didTimeout()
    func didError(_ error: Error)
}

class FightInitiationViewModel: ObservableObject {
    private let friend: User
    private let signalClient: SignalClient
    private let meeting: Meeting?
    weak var delegate: FightInitiationViewModelDelegate?

    @Published var errorMessage: String?
    @Published var hasTimedOut = false
    @Published var webRTCConnectionState: RTCIceConnectionState?

    init(
        signalClient: SignalClient,
        friend: User,
        meeting: Meeting?
    ) {
        self.friend = friend
        self.signalClient = signalClient
        self.meeting = meeting
        self.signalClient.delegate = self

        Task {
            await connect()
        }
    }

    func connect() async {
        if let meeting = meeting {
            await signalClient.joinMeeting(meeting)
        } else {
            await signalClient.joinMeeting(with: friend.id.uuidString)
        }
    }
}

extension FightInitiationViewModel: SignalClientDelegate {
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
