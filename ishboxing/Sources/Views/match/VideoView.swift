import SwiftUI
import WebRTC

struct VideoView: UIViewRepresentable {
    let videoView: RTCMTLVideoView

    func makeUIView(context: Context) -> RTCMTLVideoView {
        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // No updates needed
    }
}
