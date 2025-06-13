import Combine
import Foundation
import WebRTC

let MAX_SWIPE_POINTS = 40
let POINTS_CLEAR_DELAY: TimeInterval = 1.0

enum DragState {
    case idle
    case dragging(CGPoint)
}

final class GameEngine: ObservableObject {
    @Published public private(set) var gameState: GameState = .idle
    @Published public private(set) var countdown: Int? = nil
    @Published public private(set) var localSwipePoints: [CGPoint] = []
    @Published public private(set) var opponentSwipePoints: [CGPoint] = []
    @Published public private(set) var round = [0, 0]
    @Published public private(set) var roundResults: [[Int?]] = Array(
        repeating: [nil, nil], count: 12)
    @Published public private(set) var onOffense: Bool = false
    @Published public private(set) var fullScreenMessage: String?
    @Published public private(set) var bottomMessage: String?
    @Published public private(set) var isCountdownActive: Bool = false
    @Published public private(set) var isGameOver: Bool = false

    public var oponentIsReady: Bool = false
    public var oponentScreenRatio: CGSize = CGSize(width: 1, height: 1)
    public var readyForOffense: Bool {
        gameState == .inProgress && onOffense && oponentIsReady && oponentScreenRatio != nil
    }

    private var webRTCClient: WebRTCClient
    private var supabaseService: SupabaseService
    private var match: Match?

    private var countdownTimer: AnyCancellable?
    private let countdownPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

    func swipe(point: CGPoint?, isLocal: Bool = false, isEnd: Bool = false) {
        if isEnd || point == nil {
            // Set timer to clear points
            DispatchQueue.main.asyncAfter(deadline: .now() + POINTS_CLEAR_DELAY) {
                if isLocal {
                    self.localSwipePoints.removeAll()
                } else {
                    self.opponentSwipePoints.removeAll()
                }
            }
        } else if let point = point {
            if isLocal {
                // Add point to local points
                localSwipePoints.append(point)
                if localSwipePoints.count > MAX_SWIPE_POINTS {
                    localSwipePoints = Array(localSwipePoints.suffix(MAX_SWIPE_POINTS))
                }
                // Apply smoothing to the entire path
                smoothPoints(points: &localSwipePoints, windowSize: 5)
            } else {
                debugPrint("received swipePoint: \(point)")
                // Add point to opponent points
                let scaledPoint = CGPoint(
                    x: point.x * oponentScreenRatio.width,
                    y: point.y * oponentScreenRatio.height
                )
                opponentSwipePoints.append(scaledPoint)
                if opponentSwipePoints.count > MAX_SWIPE_POINTS {
                    opponentSwipePoints = Array(opponentSwipePoints.suffix(MAX_SWIPE_POINTS))
                }
                // Apply smoothing to the entire path
                smoothPoints(points: &opponentSwipePoints, windowSize: 5)
            }
        }
        if isLocal {
            sendSwipe(point: point)
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
}
