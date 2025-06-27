import Combine
import Foundation
import WebRTC

let MAX_SWIPE_POINTS = 40
let POINTS_CLEAR_DELAY: TimeInterval = 1.0
let DOT_PRODUCT_THRESHOLD: Double = 0.7
let MAX_HEAD_POSE_HISTORY_SIZE = 30
let REACTION_CUTOFF_TIME: TimeInterval = 0.5
let NUMBER_OF_ROUNDS = 11
let MIN_SWIPE_POINTS = 5

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
    @Published public private(set) var round = [0, 0]  // [round, user possession]
    // Format is [current user's dodges, opponent's dodges] for each round
    @Published public private(set) var roundResults: [[Int]] = Array(
        repeating: [0, 0], count: NUMBER_OF_ROUNDS)
    @Published public private(set) var onOffense: Bool = false
    @Published public private(set) var fullScreenMessage: String?
    @Published public private(set) var bottomMessage: String?
    @Published public private(set) var isCountdownActive: Bool = false
    @Published public private(set) var isGameOver: Bool = false
    @Published public private(set) var headPositionHistory: [HeadPoseObservation] = []
    @Published public private(set) var match: Match?

    @Published public private(set) var localPunchConnected: Bool = false
    @Published public private(set) var localPunchDodged: Bool = false
    @Published public private(set) var remotePunchConnected: Bool = false
    @Published public private(set) var remotePunchDodged: Bool = false

    var currentUserStreak: Int {
        var streak = 0
        for i in (0..<round[0]).reversed() {
            if roundResults[i][1] > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    var opposingUserStreak: Int {
        var streak = 0
        for i in (0..<round[0]).reversed() {
            if roundResults[i][0] > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private var waitingThrowResult: Bool = false
    private var webRTCClient: WebRTCClient
    private var supabaseService: SupabaseService

    private var countdownTimer: AnyCancellable?
    private let countdownPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let maxHistorySize = 10
    private let maxRounds = 11
    private var pauseCapturingPoseHistory: Bool = false
    private var isGatheringReaction: Bool = false

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
        DispatchQueue.main.async {
            self.gameState = state
        }
    }

    func onLocalPunchConnected() {
        // Update round
        DispatchQueue.main.async {
            if self.round[1] == 1 {
                self.round[0] += 1
                self.round[1] = 0
            } else {
                self.round[1] = 1
            }
            debugPrint("onLocalPunchConnected, moving to round \(self.round[0] + 1)")

            // Check if game is over
            if self.round[0] >= self.maxRounds {
                self.isGameOver = true
            }

            // Flip who is on offense
            self.onOffense = !self.onOffense
        }

        // Send punch connected message to opponent
        debugPrint("onLocalPunchConnected")
        let payload = RTCDataPayload(type: "punchConnected", data: Data())
        let encodedPayload = try! JSONEncoder().encode(payload)
        webRTCClient.sendData(encodedPayload)
    }

    func onLocalPunchDodged() {
        // Update round results
        DispatchQueue.main.async {
            self.roundResults[self.round[0]][0] = (self.roundResults[self.round[0]][0] ?? 0) + 1
        }

        // Send punch dodged message to opponent
        debugPrint("onLocalPunchDodged")
        let payload = RTCDataPayload(type: "punchDodged", data: Data())
        let encodedPayload = try! JSONEncoder().encode(payload)
        webRTCClient.sendData(encodedPayload)
    }

    func onRemotePunchConnected() {
        debugPrint("onRemotePunchConnected")
        DispatchQueue.main.async {
            if self.round[1] == 1 {
                self.round[0] += 1
                self.round[1] = 0
            } else {
                self.round[1] = 1
            }
            debugPrint("onRemotePunchConnected, moving to round \(self.round[0] + 1)")
        }

        // Update round results
        DispatchQueue.main.async {
            self.remotePunchConnected = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.remotePunchConnected = false
        }

        // Update round
        // Flip who is on offense
        DispatchQueue.main.async {
            self.onOffense = !self.onOffense
            self.waitingThrowResult = false
        }
    }

    func onRemotePunchDodged() {
        debugPrint("onRemotePunchDodged")

        // Update round results
        DispatchQueue.main.async {
            self.roundResults[self.round[0]][1] = (self.roundResults[self.round[0]][1] ?? 0) + 1
            self.remotePunchDodged = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.remotePunchDodged = false
        }

        DispatchQueue.main.async {
            self.waitingThrowResult = false
        }
    }

    func localSwipe(point: CGPoint?, isLocal: Bool = false) {
        if let point = point {
            DispatchQueue.main.async {
                self.localSwipePoints.append(point)
                if self.localSwipePoints.count > MAX_SWIPE_POINTS {
                    self.localSwipePoints = Array(self.localSwipePoints.suffix(MAX_SWIPE_POINTS))
                }
                self.smoothPoints(points: &self.localSwipePoints, windowSize: 5)
            }
            sendSwipe(point: point)
        } else if self.localSwipePoints.count > MIN_SWIPE_POINTS {
            DispatchQueue.main.async {
                self.waitingThrowResult = true
            }
            speedUpLocalPoints()
            // nil indicates end of throw
            DispatchQueue.main.asyncAfter(deadline: .now() + POINTS_CLEAR_DELAY) {
                self.localSwipePoints.removeAll()
            }
            sendSwipe(point: point)
        } else {
            // If the swipe is too short, remove all points
            DispatchQueue.main.async {
                self.localSwipePoints.removeAll()
            }
            sendSwipe(point: point)
        }
    }

    func speedUpLocalPoints() {
        // Used at end of local swipe to have the swipe carry on momentum across the screen

        let lastPoint = self.localSwipePoints.last
        let secondToLastPoint = self.localSwipePoints[self.localSwipePoints.count - 2]
        let dx = lastPoint!.x - secondToLastPoint.x
        let dy = lastPoint!.y - secondToLastPoint.y

        for i in 0..<1000 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.001) {
                self.localSwipePoints.append(
                    CGPoint(
                        x: lastPoint!.x + (dx * CGFloat(i)),
                        y: lastPoint!.y + (dy * CGFloat(i))
                    ))
                self.localSwipePoints.removeFirst()
            }
        }
    }

    func speedUpRemotePoints(onComplete: @escaping () -> Void) {
        // Used at end of remote swipe to have the swipe carry on momentum across the screen

        let lastPoint = self.remoteSwipePoints.last
        let secondToLastPoint = self.remoteSwipePoints[self.remoteSwipePoints.count - 2]
        let dx = lastPoint!.x - secondToLastPoint.x
        let dy = lastPoint!.y - secondToLastPoint.y

        for i in 0..<100 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.003) {
                self.remoteSwipePoints.append(
                    CGPoint(
                        x: lastPoint!.x + (dx * CGFloat(i)),
                        y: lastPoint!.y + (dy * CGFloat(i))
                    ))
                self.remoteSwipePoints.removeFirst()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }

    func remoteSwipe(point: CGPoint?) {
        if let point = point {
            // Scale the point if needed to account
            // for different screen sizes of the opponent
            let scaledPoint = CGPoint(
                x: point.x * oponentScreenRatio.width,
                y: point.y * oponentScreenRatio.height
            )
            DispatchQueue.main.async {
                self.remoteSwipePoints.append(scaledPoint)
                if self.remoteSwipePoints.count > MAX_SWIPE_POINTS {
                    self.remoteSwipePoints = Array(self.remoteSwipePoints.suffix(MAX_SWIPE_POINTS))
                }
                self.smoothPoints(points: &self.remoteSwipePoints, windowSize: 5)
            }
        } else if self.remoteSwipePoints.count > MIN_SWIPE_POINTS {
            // nil indicates end of throw
            speedUpRemotePoints {
                self.isGatheringReaction = true
            }
            self.isGatheringReaction = true
            DispatchQueue.main.asyncAfter(deadline: .now() + REACTION_CUTOFF_TIME) {
                self.isGatheringReaction = false
                self.pauseCapturingPoseHistory = true
                self.handleThrown()
                self.pauseCapturingPoseHistory = false
            }
        } else {
            // If the swipe is too short, remove all points
            DispatchQueue.main.async {
                self.remoteSwipePoints.removeAll()
            }
        }
    }

    func handleThrown() {
        // Handle thrown punch from opponent
        // A thrown punch is when the opponent's finger has lifted from the screen, which results
        // in a null swipe point being sent, indicating the end. The user then has a short window
        // to react.

        // Now we can use the dodge vector to determine if a punch was dodged
        let throwVector = calculateThrowVector()
        let dodgeVector = calculateDodgeVector()

        // Calculate dot product of normalized vectors
        let dotProduct = throwVector.x * dodgeVector.x + throwVector.y * dodgeVector.y

        let dodgeMagnitude = calculateDodgeMagnitude()

        debugPrint("dotProduct: \(dotProduct)")
        debugPrint("throwVector: \(throwVector)")
        debugPrint("dodgeVector: \(dodgeVector)")
        debugPrint("dodgeMagnitude: \(dodgeMagnitude)")

        if dodgeMagnitude < 30 || dotProduct > DOT_PRODUCT_THRESHOLD {
            // Punch connected
            DispatchQueue.main.async {
                self.localPunchConnected = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.localPunchConnected = false
            }
            onLocalPunchConnected()
        } else {
            // Punch dodged
            DispatchQueue.main.async {
                self.localPunchDodged = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.localPunchDodged = false
            }
            onLocalPunchDodged()
        }

        self.remoteSwipePoints.removeAll()
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

    private func calculateThrowVector() -> CGPoint {
        guard remoteSwipePoints.count >= 2 else {
            return CGPoint(x: 0, y: 0)
        }

        // Get the last two points from the remote swipe
        let lastPoint = remoteSwipePoints.last!
        let secondToLastPoint = remoteSwipePoints[remoteSwipePoints.count - 2]

        // Calculate vector components
        let dx = lastPoint.x - secondToLastPoint.x
        let dy = lastPoint.y - secondToLastPoint.y

        // Calculate magnitude
        let magnitude = sqrt(dx * dx + dy * dy)

        // Return normalized vector
        return CGPoint(x: dx / magnitude, y: dy / magnitude)
    }

    private func calculateDodgeMagnitude() -> CGFloat {
        guard headPositionHistory.count >= 2 else {
            return 0
        }

        let lastBox = headPositionHistory.last!.boundingBox
        let recentBox = headPositionHistory.first!.boundingBox

        let dx = lastBox.midX - recentBox.midX
        let dy = lastBox.midY - recentBox.midY

        return sqrt(dx * dx + dy * dy)
    }

    private func calculateDodgeVector() -> CGPoint {
        guard headPositionHistory.count >= 2 else {
            return CGPoint(x: 0, y: 0)
        }

        // Get the last two head positions using bounding box centers
        let lastBox = headPositionHistory.last!.boundingBox
        let recentBox = headPositionHistory.first!.boundingBox

        // Convert from detection space to normalized coordinates (0-1)
        // Flip x coordinate to match mirrored video view
        let lastCenter = CGPoint(
            x: 1.0 - (lastBox.midX / Constants.HeadPoseDetection.targetSize),  // Flip x coordinate
            y: lastBox.midY / Constants.HeadPoseDetection.targetSize
        )
        let recentCenter = CGPoint(
            x: 1.0 - (recentBox.midX / Constants.HeadPoseDetection.targetSize),  // Flip x coordinate
            y: recentBox.midY / Constants.HeadPoseDetection.targetSize
        )

        // Calculate the vector from the second to last position to the last position
        let dx = lastCenter.x - recentCenter.x
        let dy = lastCenter.y - recentCenter.y

        // Calculate magnitude of the vector
        let magnitude = sqrt(dx * dx + dy * dy)

        // Return normalized vector as start and end points
        return CGPoint(x: dx / magnitude, y: dy / magnitude)
    }
}

extension GameEngine: HeadPoseDetectionDelegate {
    func headPoseDetectionRenderer(
        _ renderer: HeadPoseDetectionRenderer, didUpdateHeadPose headPose: HeadPoseObservation
    ) {
        if self.pauseCapturingPoseHistory {
            return
        }

        // Update history
        if self.isGatheringReaction {
            // Only append if dx vector direction is same as the vector for whole history
            // with the exception of when the magnitude of the history vector is close to 0 (< 0.05)
            // This is because:
            // 1. There might be small perturbations in the vector due to noise at the beginning of the gathering stage
            // 2. When the head dodges, the head always returns to the resting position, and we don't want to accidentally
            // gather any data from the return motion
            let historyVector = calculateDodgeVector()
            let historyMagnitude = sqrt(
                historyVector.x * historyVector.x + historyVector.y * historyVector.y)
            let historyNormalized = CGPoint(
                x: historyVector.x / historyMagnitude,
                y: historyVector.y / historyMagnitude
            )

            let dx = headPose.boundingBox.midX - headPositionHistory.last!.boundingBox.midX
            let dy = headPose.boundingBox.midY - headPositionHistory.last!.boundingBox.midY
            let dxMagnitude = sqrt(dx * dx)
            let dyMagnitude = sqrt(dy * dy)
            let dNormalized = CGPoint(x: dx / dxMagnitude, y: dy / dyMagnitude)

            let dotProduct =
                historyNormalized.x * dNormalized.x + historyNormalized.y * dNormalized.y

            if dotProduct > 0 || historyMagnitude < 10 {
                headPositionHistory.append(headPose)
            }

        } else {
            headPositionHistory.append(headPose)
        }

        // Keep history at max size
        if headPositionHistory.count > maxHistorySize {
            headPositionHistory.removeFirst()
        }
    }
}
