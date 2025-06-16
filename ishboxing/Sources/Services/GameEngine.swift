import Combine
import Foundation
import WebRTC

let MAX_SWIPE_POINTS = 40
let POINTS_CLEAR_DELAY: TimeInterval = 0.5
let DOT_PRODUCT_THRESHOLD: Double = 0.7
let MAX_HEAD_POSE_HISTORY_SIZE = 20

enum DragState {
    case idle
    case dragging(CGPoint)
}

final class GameEngine: ObservableObject {
    /*
    GameEngine is responsible for managing the game state and logic.
    It is responsible for:
    - Managing the game state
    - Managing the game logic
    - Managing the game data (including that sent over WebRTC)
    */

    @Published public private(set) var gameState: GameState = .idle
    @Published public private(set) var countdown: Int? = nil
    @Published public private(set) var localSwipePoints: [CGPoint] = []
    @Published public private(set) var remoteSwipePoints: [CGPoint] = []
    @Published public private(set) var round = 0
    // Format is [current user's dodges, opponent's dodges] for each round
    @Published public private(set) var roundResults: [[Int?]] = Array(
        repeating: [nil, nil], count: 12)
    @Published public private(set) var onOffense: Bool = false
    @Published public private(set) var fullScreenMessage: String?
    @Published public private(set) var bottomMessage: String?
    @Published public private(set) var isCountdownActive: Bool = false
    @Published public private(set) var isGameOver: Bool = false
    @Published public private(set) var dodgeVector: CGVector?

    private var waitingThrowResult: Bool = false
    private var webRTCClient: WebRTCClient
    private var supabaseService: SupabaseService
    private var match: Match?

    private var countdownTimer: AnyCancellable?
    private let countdownPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var headPositionHistory: [HeadPoseObservation] = []
    private let maxHistorySize = 10

    public var oponentIsReady: Bool = false
    public var oponentScreenRatio: CGSize = CGSize(width: 1, height: 1)
    public var readyForOffense: Bool {
        gameState == .inProgress && onOffense && oponentIsReady && oponentScreenRatio != nil
            && !waitingThrowResult
    }

    init(webRTCClient: WebRTCClient, supabaseService: SupabaseService) {
        self.webRTCClient = webRTCClient
        self.supabaseService = supabaseService
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
            return userId == match.from.id
        } catch {
            return false
        }
    }

    func setMatch(match: Match) {
        self.match = match
        // Set the person who didn't initiate the match to be on offense first
        // Can possibly change this to a coin flip later
        Task {
            self.onOffense = await !self.didInitiateMatch()
        }
    }

    func setState(state: GameState) {
        self.gameState = state
    }

    func onLocalPunchConnected() {
        // Update round
        round += 1

        // Flip who is on offense
        onOffense = !onOffense

        // Send punch connected message to opponent
        let payload = RTCDataPayload(type: "punchConnected", data: Data())
        let encodedPayload = try! JSONEncoder().encode(payload)
        webRTCClient.sendData(encodedPayload)
    }

    func onLocalPunchDodged() {
        // Update round results
        roundResults[round][0] = (roundResults[round][0] ?? 0) + 1

        // Send punch dodged message to opponent
        let payload = RTCDataPayload(type: "punchDodged", data: Data())
        let encodedPayload = try! JSONEncoder().encode(payload)
        webRTCClient.sendData(encodedPayload)
    }

    func onRemotePunchConnected() {
        // Update round results
        roundResults[round][1] = (roundResults[round][1] ?? 0) + 1

        // Update round
        // Flip who is on offense
        onOffense = !onOffense
    }

    func onRemotePunchDodged() {
        // Update round results
        roundResults[round][1] = (roundResults[round][1] ?? 0) + 1
    }

    func localSwipe(point: CGPoint?, isLocal: Bool = false) {
        if let point = point {
            localSwipePoints.append(point)
            if localSwipePoints.count > MAX_SWIPE_POINTS {
                localSwipePoints = Array(localSwipePoints.suffix(MAX_SWIPE_POINTS))
            }
            smoothPoints(points: &localSwipePoints, windowSize: 5)
        } else {
            // nil indicates end of throw
            DispatchQueue.main.asyncAfter(deadline: .now() + POINTS_CLEAR_DELAY) {
                self.localSwipePoints.removeAll()
            }
            waitingThrowResult = true
        }

        sendSwipe(point: point)
    }

    func remoteSwipe(point: CGPoint?) {
        if let point = point {
            // Scale the point if needed to account
            // for different screen sizes of the opponent
            let scaledPoint = CGPoint(
                x: point.x * oponentScreenRatio.width,
                y: point.y * oponentScreenRatio.height
            )
            remoteSwipePoints.append(scaledPoint)
            if remoteSwipePoints.count > MAX_SWIPE_POINTS {
                remoteSwipePoints = Array(remoteSwipePoints.suffix(MAX_SWIPE_POINTS))
            }
            smoothPoints(points: &remoteSwipePoints, windowSize: 5)
        } else {
            // nil indicates end of throw
            DispatchQueue.main.asyncAfter(deadline: .now() + POINTS_CLEAR_DELAY) {
                self.remoteSwipePoints.removeAll()
            }
            handleThrown()
        }
    }

    func handleThrown() {
        // Handle thrown punch from opponent

        // Now we can use the dodge vector to determine if a punch was dodged
        if let dodgeVector = dodgeVector {
            let magnitude = sqrt(dodgeVector.dx * dodgeVector.dx + dodgeVector.dy * dodgeVector.dy)
            if magnitude > 0.1 {  // Threshold for successful dodge
                onLocalPunchDodged()
            } else {
                onLocalPunchConnected()
            }
        } else {
            // If we don't have a dodge vector, assume the punch connected
            onLocalPunchConnected()
        }
    }

    func smoothPoints(points: inout [CGPoint], windowSize: Int) {
        guard points.count > windowSize else { return }

        // Create a copy of the points for smoothing
        var smoothedPoints = points

        // Apply moving average smoothing
        for i in 0..<points.count {
            let start = max(0, i - windowSize / 2)
            let end = min(points.count - 1, i + windowSize / 2)
            let window = points[start...end]

            let sumX = window.reduce(0) { $0 + $1.x }
            let sumY = window.reduce(0) { $0 + $1.y }
            let count = Double(window.count)

            smoothedPoints[i] = CGPoint(
                x: sumX / count,
                y: sumY / count
            )
        }

        // Update the original points with smoothed values
        points = smoothedPoints
    }

    func sendSwipe(point: CGPoint?) {
        // Create a dictionary with x and y coordinates
        let pointData: Data
        if let point = point {
            let pointDict = ["x": point.x, "y": point.y]
            pointData = try! JSONEncoder().encode(pointDict)
        } else {
            pointData = Data()  // Empty data for nil point
        }
        let payload = RTCDataPayload(type: "swipePoint", data: pointData)
        let encodedPayload = try! JSONEncoder().encode(payload)
        webRTCClient.sendData(encodedPayload)
    }

    func sendReady() {
        let payload = RTCDataPayload(type: "ready", data: Data())
        let encodedPayload = try! JSONEncoder().encode(payload)
        webRTCClient.sendData(encodedPayload)
    }

    func sendScreenSize() {
        let screenSize = UIScreen.main.bounds
        let screenSizeDict = ["width": screenSize.width, "height": screenSize.height]
        let screenSizeData = try! JSONEncoder().encode(screenSizeDict)
        let payload = RTCDataPayload(type: "screenSize", data: screenSizeData)
        let encodedPayload = try! JSONEncoder().encode(payload)
        self.webRTCClient.sendData(encodedPayload)
    }

    public func start() {
        sendScreenSize()
        self.gameState = .starting
        self.countdown = 5
        self.isCountdownActive = true

        countdownTimer =
            countdownPublisher
            .sink { [weak self] _ in
                guard let self = self else { return }
                if let currentCount = self.countdown {
                    if currentCount > 1 {
                        self.countdown = currentCount - 1
                    } else {
                        self.countdown = nil
                        self.isCountdownActive = false
                        self.gameState = .inProgress
                        self.sendReady()
                        self.countdownTimer?.cancel()
                    }
                }
            }
    }

    private func calculateDodgeVector(from history: [CGPoint]) -> CGVector {
        guard history.count >= 2 else { return CGVector(dx: 0, dy: 0) }

        // Calculate the average movement over the last few frames
        var totalDx: CGFloat = 0
        var totalDy: CGFloat = 0
        let count = CGFloat(history.count - 1)

        for i in 1..<history.count {
            let current = history[i]
            let previous = history[i - 1]
            totalDx += current.x - previous.x
            totalDy += current.y - previous.y
        }

        // Normalize the vector
        let dx = totalDx / count
        let dy = totalDy / count
        let magnitude = sqrt(dx * dx + dy * dy)

        // Only return significant movements
        if magnitude > 0.05 {  // Threshold for significant movement
            return CGVector(dx: dx, dy: dy)
        }

        return CGVector(dx: 0, dy: 0)
    }
}

extension GameEngine: HeadPoseDetectionDelegate {
    func headPoseDetectionRenderer(
        _ renderer: HeadPoseDetectionRenderer, didUpdateHeadPose headPose: HeadPoseObservation
    ) {
        // Update history
        headPositionHistory.append(headPose)
        if headPositionHistory.count > maxHistorySize {
            headPositionHistory.removeFirst()
        }
    }
}
