import AVFoundation
import Foundation
import Supabase
import SwiftUI
import WebRTC

struct MatchView: View {
    @Environment(\.dismiss) var dismiss
    let friend: User
    let supabaseService = SupabaseService.shared
    let webRTCClient: WebRTCClient
    let headPoseDetectionRenderer: HeadPoseDetectionRenderer

    @StateObject private var viewModel: MatchViewModel
    @StateObject private var gameEngine: GameEngine
    @State private var localVideoView: RTCMTLVideoView?
    @State private var remoteVideoView: RTCMTLVideoView?
    @State private var hasRemoteVideoTrack = false
    @State private var match: Match?
    @State private var currentUsername: String = ""

    init(friend: User, match: Match?, onDismiss: @escaping () -> Void) {
        self.friend = friend
        self._match = State(initialValue: match)

        let webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers)
        self.webRTCClient = webRTCClient

        let gameEngine = GameEngine(webRTCClient: webRTCClient, supabaseService: supabaseService)
        self._gameEngine = StateObject(wrappedValue: gameEngine)

        let signalClient = SignalClient(supabase: supabaseService, webRTCClient: webRTCClient)
        self._viewModel = StateObject(
            wrappedValue: MatchViewModel(
                signalClient: signalClient,
                webRTCClient: webRTCClient,
                gameEngine: gameEngine,
                friend: friend,
                match: match,
                onDismiss: onDismiss
            ))
        let headPoseDetectionRenderer = HeadPoseDetectionRenderer(delegate: gameEngine)
        self.headPoseDetectionRenderer = headPoseDetectionRenderer
        self.headPoseDetectionRenderer.delegate = gameEngine
    }

    var body: some View {
        ZStack {
            // Background color
            Color.black.edgesIgnoringSafeArea(.all)

            // Remote video view (full screen)
            if let remoteVideoView = remoteVideoView {
                VideoView(videoView: remoteVideoView)
                    .edgesIgnoringSafeArea(.all)
                    .blur(radius: viewModel.webRTCConnectionState == .disconnected ? 10 : 0)
                    .onAppear {
                        webRTCClient.renderRemoteVideo(to: remoteVideoView)
                    }
                    .overlay(
                        VideoBorderView(
                            isLocal: false,
                            punchConnected: gameEngine.remotePunchConnected,
                            punchDodged: gameEngine.remotePunchDodged
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else {
                // Placeholder while waiting for remote video
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .edgesIgnoringSafeArea(.all)
            }

            // Local video view (smaller, top right corner)
            if let localVideoView = localVideoView {
                ZStack {
                    VideoView(videoView: localVideoView)
                        .frame(width: 120, height: 160)
                        .cornerRadius(24)
                        .overlay(
                            VideoBorderView(
                                isLocal: true,
                                punchConnected: gameEngine.localPunchConnected,
                                punchDodged: gameEngine.localPunchDodged
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                    // Microphone button
                    Button(action: {
                        if viewModel.isMuted {
                            viewModel.unmuteAudio()
                        } else {
                            viewModel.muteAudio()
                        }
                    }) {
                        Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    .position(x: 100, y: 20)
                }
                .frame(width: 120, height: 160)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            // Swipe Paths
            GlowingPath(points: gameEngine.localSwipePoints, isLocal: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            GlowingPath(points: gameEngine.remoteSwipePoints, isLocal: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // Full screen message
            if let fullScreenMessage = gameEngine.fullScreenMessage {
                Text(fullScreenMessage)
                    .font(.bangers(size: 120))
                    .foregroundColor(.white)
            }

            // Bottom message
            if let bottomMessage = gameEngine.bottomMessage {
                Text(bottomMessage)
                    .font(.bangers(size: 120))
                    .foregroundColor(.white)
            }

            // Gesture overlay
            if viewModel.webRTCSignalingState == .stable {
                GestureOverlay(
                    isEnabled: gameEngine.readyForOffense,
                    onSwipe: { point in
                        gameEngine.localSwipe(point: point, isLocal: true)
                    }
                )
            }

            // Score Display
            ScoreDisplay(
                currentUsername: currentUsername,
                opposingUsername: friend.username ?? "",
                currentUserStreak: gameEngine.currentUserStreak,
                opposingUserStreak: gameEngine.opposingUserStreak
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 20)
            .padding(.top, 20)

            // Leave button
            Button(action: {
                viewModel.endMatch()
                dismiss()
            }) {
                Text("LEAVE ")
                    .font(.bangers(size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .background(
                Capsule()
                    .fill(Color.ishRed)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 20)
            .padding(.bottom, 20)

            // Countdown overlay
            if let countdown = gameEngine.countdown {
                CountdownOverlay(
                    countdown: countdown,
                    isActive: gameEngine.isCountdownActive
                )
            }

            // Disconnected overlay
            if viewModel.webRTCConnectionState == .disconnected {
                DisconnectedOverlay(
                    friendUsername: friend.username,
                    onDismiss: {
                        viewModel.endMatch()
                        dismiss()
                    }
                )
            }

            // Round Results
            RoundResults(
                roundResults: gameEngine.roundResults,
                currentRound: gameEngine.round
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            setupVideoViews()
            Task {
                currentUsername = await supabaseService.getUser()?.username ?? ""
            }
        }
    }

    private func setupVideoViews() {
        // Setup local video view
        let localView = RTCMTLVideoView()
        localView.videoContentMode = .scaleAspectFill
        localView.backgroundColor = .black
        localVideoView = localView
        localView.transform = CGAffineTransform(scaleX: -1, y: 1)
        webRTCClient.startCaptureLocalVideo(renderer: localView)

        // Add head pose detection renderer
        webRTCClient.startCaptureLocalVideo(renderer: headPoseDetectionRenderer)

        // Setup remote video view
        let remoteView = RTCMTLVideoView()
        remoteView.videoContentMode = .scaleAspectFill
        remoteView.backgroundColor = .black
        remoteVideoView = remoteView
        remoteView.transform = CGAffineTransform(scaleX: -1, y: 1)
    }
}
