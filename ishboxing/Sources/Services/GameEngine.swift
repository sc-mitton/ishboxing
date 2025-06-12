import Foundation
import WebRTC

final class GameEngine: ObservableObject {
    @Published var gameState: GameState = .idle
    @Published var countdown: Int?

    private var webRTCClient: WebRTCClient
    private var match: Match?
    private var onOffense: User?
    private var countdownTimer: Timer?

    init(webRTCClient: WebRTCClient) {
        self.webRTCClient = webRTCClient
    }

    func setMatch(match: Match) {
        self.match = match
    }

    func startGame() {
        gameState = .starting
        self.countdown = 5

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if self.countdown! > 0 {
                self.countdown! -= 1
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                self.countdown = nil
                self.gameState = .inProgress
            }
        }
    }
}
