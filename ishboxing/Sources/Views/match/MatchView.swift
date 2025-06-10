import Foundation
import Supabase
import SwiftUI
import WebRTC

struct MatchView: View {
    @Environment(\.dismiss) var dismiss
    let friend: User
    let match: Match?
    let supabaseService = SupabaseService.shared
    let webRTCClient: WebRTCClient

    @StateObject private var viewModel: MatchViewModel
    @State private var localVideoView: RTCMTLVideoView?
    @State private var remoteVideoView: RTCMTLVideoView?

    init(friend: User, match: Match?, onDismiss: @escaping () -> Void) {
        self.match = match
        self.friend = friend

        let webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers)
        self.webRTCClient = webRTCClient
        let signalClient = SignalClient(supabase: supabaseService, webRTCClient: webRTCClient)

        self._viewModel = StateObject(
            wrappedValue: MatchViewModel(
                signalClient: signalClient,
                webRTCClient: webRTCClient,
                friend: friend,
                match: match,
                onDismiss: onDismiss
            ))
    }

    var body: some View {
        ZStack {
            // Background color
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                // Remote video view (larger)
                if let remoteVideoView = remoteVideoView {
                    VideoView(videoView: remoteVideoView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(9 / 16, contentMode: .fit)
                        .cornerRadius(12)
                        .padding()
                }

                // Local video view (smaller, overlay)
                if let localVideoView = localVideoView {
                    VideoView(videoView: localVideoView)
                        .frame(width: 120, height: 160)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .padding()
                }

                // Connection status
                if let state = viewModel.webRTCConnectionState {
                    Text("Connection: \(state.rawValue)")
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)

            // Overlay controls
            MatchControlsView(viewModel: viewModel)
        }
        .onAppear {
            setupVideoViews()
        }
    }

    private func setupVideoViews() {
        // Setup local video view
        let localView = RTCMTLVideoView()
        localVideoView = localView
        debugPrint("Setting up local video view")
        webRTCClient.startCaptureLocalVideo(renderer: localView)

        // Setup remote video view
        let remoteView = RTCMTLVideoView()
        remoteVideoView = remoteView
        debugPrint("Setting up remote video view")
        webRTCClient.renderRemoteVideo(to: remoteView)
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
