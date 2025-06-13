import Foundation
import WebRTC

let MAX_SWIPE_POINTS = 20
let POINTS_CLEAR_DELAY: TimeInterval = 2.0

final class GameEngine: ObservableObject {
    @Published public private(set) var gameState: GameState = .idle
    @Published public private(set) var countdown: Int?
    @Published public private(set) var localSwipePoints: [CGPoint] = []
    @Published public private(set) var opponentSwipePoints: [CGPoint] = []
    @Published public private(set) var round = [0, 0]
    @Published public private(set) var roundResults: [[Int?]] = Array(
        repeating: [nil, nil], count: 12)
    @Published public private(set) var onOffense: Bool = false
    @Published public private(set) var fullScreenMessage: String?
    @Published public private(set) var bottomMessage: String?

    private var webRTCClient: WebRTCClient
    private var supabaseService: SupabaseService
    private var match: Match?
    private var countdownTimer: Timer?
    private var pointsClearTimer: Timer?

    init(webRTCClient: WebRTCClient, supabaseService: SupabaseService) {
        self.webRTCClient = webRTCClient
        self.supabaseService = supabaseService

        // Set the person who didn't initiate the match to be on offense first
        // Can possibly change this to a coin flip later
        Task {
            self.onOffense = await !self.didInitiateMatch()
        }
    }

    public func didInitiateMatch() async -> Bool {
        guard let match = match else {
            return false
        }
        do {
            let session = try await supabaseService.client.auth.session
            let userId = session.user.id
            debugPrint("didInitiateMatch: \(userId == match.from.id)")
            return userId == match.from.id
        } catch {
            return false
        }
    }

    func setMatch(match: Match) {
        self.match = match
    }

    func setState(state: GameState) {
        self.gameState = state
    }

    func onPunchConnected() {
        round[1] = round[1] > 0 ? round[1] + 1 : 1
        round[0] += 1

        // Flip who is on offense
        onOffense = !onOffense
    }

    func onPunchDodged() {
        roundResults[round[0]][round[1]] = (roundResults[round[0]][round[1]] ?? 0) + 1
    }

    func swipe(point: CGPoint, isLocal: Bool = false) {
        // Reset the clear timer
        pointsClearTimer?.invalidate()
        pointsClearTimer = Timer.scheduledTimer(
            withTimeInterval: POINTS_CLEAR_DELAY, repeats: false
        ) { [weak self] _ in
            if isLocal {
                self?.localSwipePoints.removeAll()
            } else {
                self?.opponentSwipePoints.removeAll()
            }
        }

        if isLocal {
            localSwipePoints.append(point)
            if localSwipePoints.count > MAX_SWIPE_POINTS {
                localSwipePoints = Array(localSwipePoints.suffix(MAX_SWIPE_POINTS))
            }
            smoothPoints(points: &localSwipePoints, windowSize: 4)
            sendSwipe(point: localSwipePoints.last!)
        } else {
            opponentSwipePoints.append(point)
            if opponentSwipePoints.count > MAX_SWIPE_POINTS {
                opponentSwipePoints = Array(opponentSwipePoints.suffix(MAX_SWIPE_POINTS))
            }
            smoothPoints(points: &opponentSwipePoints, windowSize: 4)
            sendSwipe(point: opponentSwipePoints.last!)
        }
    }

    func smoothPoints(points: inout [CGPoint], windowSize: Int) {
        guard points.count > windowSize else { return }

        for i in 0..<(points.count - windowSize) {
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0

            // Calculate average of next windowSize points
            for j in 0..<windowSize {
                sumX += points[i + j].x
                sumY += points[i + j].y
            }

            // Replace current point with average
            points[i] = CGPoint(
                x: sumX / CGFloat(windowSize),
                y: sumY / CGFloat(windowSize)
            )
        }
    }

    func sendSwipe(point: CGPoint) {
        // Create a dictionary with x and y coordinates
        let pointDict = ["x": point.x, "y": point.y]
        let pointData = try! JSONEncoder().encode(pointDict)
        let payload = RTCDataPayload(type: "swipePoint", data: pointData)
        let encodedPayload = try! JSONEncoder().encode(payload)
        webRTCClient.sendData(encodedPayload)
    }

    private func startGame() {
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
