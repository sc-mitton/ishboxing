import Combine
import Foundation
import WebRTC

let MAX_SWIPE_POINTS = 40
let POINTS_CLEAR_DELAY: TimeInterval = 0.5
let DOT_PRODUCT_THRESHOLD: Double = 0.8

enum DragState {
    case idle
    case dragging(CGPoint)
}

final class GameEngine: ObservableObject {
    @Published public private(set) var gameState: GameState = .idle
    @Published public private(set) var countdown: Int? = nil
    @Published public private(set) var localSwipePoints: [CGPoint] = []
    @Published public private(set) var remoteSwipePoints: [CGPoint] = []
    @Published public private(set) var round = [0, 0]
    @Published public private(set) var roundResults: [[Int?]] = Array(
        repeating: [nil, nil], count: 12)
    @Published public private(set) var onOffense: Bool = false
    @Published public private(set) var fullScreenMessage: String?
    @Published public private(set) var bottomMessage: String?
    @Published public private(set) var isCountdownActive: Bool = false
    @Published public private(set) var isGameOver: Bool = false

    private var waitingThrowResult: Bool = false
    private var webRTCClient: WebRTCClient
    private var supabaseService: SupabaseService
    private var match: Match?

    private var countdownTimer: AnyCancellable?
    private let countdownPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

    func onPunchConnected() {
        round[1] = round[1] > 0 ? round[1] + 1 : 1
        round[0] += 1

        // Flip who is on offense
        onOffense = !onOffense
    }

    func onPunchDodged() {
        roundResults[round[0]][round[1]] = (roundResults[round[0]][round[1]] ?? 0) + 1
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
        // TODO: Implement punch handling
        // 1. Determine the direction of the throw from the remote points list
        // 2. Simultaneously, determine the direction of the dodge
        // (from head movements of the user, determined by keypoint detection model)
        // 3. Determine if the throw connected or not by the dot product of the throw vector and the dodge vector
        // if the dot product is between .8 and 1, then the direction is the same and the throw connected
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
}
