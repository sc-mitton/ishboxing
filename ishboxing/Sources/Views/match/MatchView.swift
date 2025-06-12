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

    @StateObject private var viewModel: MatchViewModel
    @ObservedObject private var gameEngine: GameEngine
    @State private var localVideoView: RTCMTLVideoView?
    @State private var remoteVideoView: RTCMTLVideoView?
    @State private var hasRemoteVideoTrack = false
    @State private var match: Match?

    init(friend: User, match: Match?, onDismiss: @escaping () -> Void) {
        self.friend = friend
        self._match = State(initialValue: match)

        let webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers)
        self.webRTCClient = webRTCClient
        let signalClient = SignalClient(supabase: supabaseService, webRTCClient: webRTCClient)

        let gameEngine = GameEngine(webRTCClient: webRTCClient)
        self._gameEngine = ObservedObject(wrappedValue: gameEngine)

        self._viewModel = StateObject(
            wrappedValue: MatchViewModel(
                signalClient: signalClient,
                webRTCClient: webRTCClient,
                gameEngine: gameEngine,
                friend: friend,
                match: match,
                onDismiss: onDismiss
            ))
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
                        debugPrint("Remote video view appeared")
                        webRTCClient.renderRemoteVideo(to: remoteVideoView)
                    }
            } else {
                // Placeholder while waiting for remote video
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .edgesIgnoringSafeArea(.all)
            }

            // Local video view (smaller, top right corner)
            if let localVideoView = localVideoView {
                VideoView(videoView: localVideoView)
                    .frame(width: 120, height: 160)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.ishBlue, lineWidth: 4)
                    )
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .onAppear {
                        debugPrint("Local video view appeared")
                    }
            }

            // Disconnected overlay
            if viewModel.webRTCConnectionState == .disconnected {
                VStack(spacing: 20) {
                    Text("\(friend.username) has left the match")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Button(action: {
                        dismiss()
                    }) {
                        Text("End Match ")
                            .font(.bangers(size: 24))
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.ishBlue)
                            .cornerRadius(25)
                    }
                }
                .padding(30)
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
            }

            // Overlay controls
            MatchControlsView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Countdown overlay
            if let countdown = gameEngine.countdown {
                Text("\(countdown) ")
                    .font(.bangers(size: 120))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.5))
            }
        }
        .onAppear {
            setupVideoViews()
        }
        .onChange(of: viewModel.webRTCConnectionState) { oldState, newState in
            if newState == .connected {
                // Re-render remote video when connection is established
                if let remoteView = remoteVideoView {
                    webRTCClient.renderRemoteVideo(to: remoteView)
                }
                gameEngine.startGame()
            }
        }
    }

    private func setupVideoViews() {
        // Setup local video view
        let localView = RTCMTLVideoView()
        localView.videoContentMode = .scaleAspectFill
        localView.backgroundColor = .black
        localVideoView = localView
        webRTCClient.startCaptureLocalVideo(renderer: localView)

        // Setup remote video view
        let remoteView = RTCMTLVideoView()
        remoteView.videoContentMode = .scaleAspectFill
        remoteView.backgroundColor = .black
        remoteVideoView = remoteView
    }
}

// Helper view to wrap RTCEAGLVideoView
struct VideoView: UIViewRepresentable {
    let videoView: RTCMTLVideoView

    func makeUIView(context: Context) -> RTCMTLVideoView {
        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // No updates needed
    }
}
