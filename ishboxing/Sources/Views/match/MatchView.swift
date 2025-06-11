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

            // Remote video view (full screen)
            if let remoteVideoView = remoteVideoView {
                VideoView(videoView: remoteVideoView)
                    .edgesIgnoringSafeArea(.all)
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
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            // Overlay controls
            MatchControlsView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            }
        }
    }

    private func setupVideoViews() {
        // Setup local video view
        let localView = RTCMTLVideoView()
        localView.videoContentMode = .scaleAspectFill
        localVideoView = localView
        webRTCClient.startCaptureLocalVideo(renderer: localView)

        // Setup remote video view
        let remoteView = RTCMTLVideoView()
        remoteView.videoContentMode = .scaleAspectFill
        remoteVideoView = remoteView
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
