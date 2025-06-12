import Foundation
import WebRTC

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
}

protocol WebRTCClientSignalingDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didGenerate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didChangeSignalingState state: RTCSignalingState)
}

final class WebRTCClient: NSObject {

    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
    // A new RTCPeerConnection should be created every new call, but the factory is shared.
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()

    weak var delegate: WebRTCClientDelegate?
    weak var signalingDelegate: WebRTCClientSignalingDelegate?
    private let peerConnection: RTCPeerConnection
    private let rtcAudioSession = RTCAudioSession.sharedInstance()
    private let audioQueue = DispatchQueue(label: "audio")
    private let mediaConstrains = [
        kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
        kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue,
    ]
    private var videoCapturer: RTCVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var localDataChannel: RTCDataChannel?
    private var remoteDataChannel: RTCDataChannel?
    private var localVideoRenderer: RTCVideoRenderer?
    private var remoteVideoRenderer: RTCVideoRenderer?

    public var hasExchangedSDP: Bool = false

    @available(*, unavailable)
    override init() {
        fatalError("WebRTCClient:init is unavailable")
    }

    required init(iceServers: [String]) {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: iceServers)]

        // Unified plan is more superior than planB
        config.sdpSemantics = .unifiedPlan

        // gatherContinually will let WebRTC to listen to any network changes and
        // send any new candidates to the other client
        config.continualGatheringPolicy = .gatherContinually

        // Enable DTLS-SRTP key agreement
        config.bundlePolicy = .maxBundle

        // Define media constraints. DtlsSrtpKeyAgreement is required to be true to be able to connect with web browsers.
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])

        guard
            let peerConnection = WebRTCClient.factory.peerConnection(
                with: config, constraints: constraints, delegate: nil)
        else {
            fatalError("Could not create new RTCPeerConnection")
        }

        self.peerConnection = peerConnection

        super.init()
        self.createMediaSenders()
        self.createDataChannel()
        self.configureAudioSession()
        self.peerConnection.delegate = self
    }

    // MARK: Signaling
    func offer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(
            mandatoryConstraints: self.mediaConstrains,
            optionalConstraints: nil)
        self.peerConnection.offer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }

            self.peerConnection.setLocalDescription(
                sdp,
                completionHandler: { (error) in
                    completion(sdp)
                })
        }
    }

    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(
            mandatoryConstraints: self.mediaConstrains,
            optionalConstraints: nil)
        self.peerConnection.answer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }

            self.peerConnection.setLocalDescription(
                sdp,
                completionHandler: { (error) in
                    completion(sdp)
                })
        }
    }

    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        self.peerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
    }

    func set(remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> Void) {
        self.peerConnection.add(remoteCandidate, completionHandler: completion)
    }

    // MARK: Media
    func startCaptureLocalVideo(renderer: RTCVideoRenderer) {
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else {
            debugPrint("Failed to get camera capturer")
            return
        }
        self.localVideoRenderer = renderer
        debugPrint("Local video renderer set")

        guard
            let frontCamera: AVCaptureDevice =
                (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }),
            let format =
                (RTCCameraVideoCapturer.supportedFormats(for: frontCamera).sorted {
                    (f1, f2) -> Bool in
                    let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
                    let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
                    return width1 < width2
                }).last,
            let fps =
                (format.videoSupportedFrameRateRanges.sorted {
                    return $0.maxFrameRate < $1.maxFrameRate
                }.last)
        else {
            debugPrint("Failed to setup camera capture")
            return
        }

        debugPrint("Starting camera capture with format: \(format)")
        capturer.startCapture(
            with: frontCamera,
            format: format,
            fps: Int(fps.maxFrameRate))

        if let localTrack = self.localVideoTrack {
            debugPrint("Adding local video track to renderer")
            localTrack.add(renderer)
        } else {
            debugPrint("No local video track available")
        }
    }

    func stopCaptureLocalVideo() {
        if let renderer = self.localVideoRenderer {
            self.localVideoTrack?.remove(renderer)
            self.localVideoRenderer = nil
        }
    }

    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        debugPrint("Attempting to render remote video to renderer")
        self.remoteVideoRenderer = renderer
        if let track = self.remoteVideoTrack {
            debugPrint("Adding remote video track to renderer")
            track.add(renderer)
        } else {
            debugPrint("No remote video track available for rendering")
        }
    }

    private func configureAudioSession() {
        self.rtcAudioSession.lockForConfiguration()
        do {
            try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord)
            try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat)
        } catch let error {
            debugPrint("Error changeing AVAudioSession category: \(error)")
        }
        self.rtcAudioSession.unlockForConfiguration()
    }

    private func createMediaSenders() {
        let streamId = "stream"

        // Audio
        let audioTrack = self.createAudioTrack()
        debugPrint("adding audio track")
        self.peerConnection.add(audioTrack, streamIds: [streamId])

        // Video
        let videoTrack = self.createVideoTrack()
        self.localVideoTrack = videoTrack
        debugPrint("adding video track")
        self.peerConnection.add(videoTrack, streamIds: [streamId])
    }

    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = WebRTCClient.factory.audioSource(with: audioConstrains)
        let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: "audio0")
        return audioTrack
    }

    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = WebRTCClient.factory.videoSource()

        #if targetEnvironment(simulator)
            self.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
            self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif

        let videoTrack = WebRTCClient.factory.videoTrack(with: videoSource, trackId: "video0")
        debugPrint("Created local video track: \(videoTrack)")
        debugPrint("Local video track enabled: \(videoTrack.isEnabled)")
        debugPrint("Local video track readyState: \(videoTrack.readyState)")
        return videoTrack
    }

    // MARK: Data Channels
    func createDataChannel() {
        let config = RTCDataChannelConfiguration()
        guard
            let dataChannel = self.peerConnection.dataChannel(
                forLabel: "WebRTCData", configuration: config)
        else {
            debugPrint("Warning: Couldn't create data channel.")
            return
        }
        dataChannel.delegate = self
        self.remoteDataChannel = dataChannel
    }

    func sendData(_ data: Data) {
        let buffer = RTCDataBuffer(data: data, isBinary: true)
        self.remoteDataChannel?.sendData(buffer)
    }

    func close() {
        debugPrint("Closing WebRTC connection")
        self.peerConnection.close()

        // Safely remove local video track from renderer
        if let renderer = self.localVideoRenderer,
            let videoTrack = self.localVideoTrack
        {
            videoTrack.remove(renderer)
        }

        // Safely stop camera capture
        if let capturer = self.videoCapturer as? RTCCameraVideoCapturer {
            capturer.stopCapture()
        }

        // Clear all references
        self.localVideoTrack = nil
        self.localVideoRenderer = nil
        self.remoteVideoTrack = nil
        self.localDataChannel = nil
        self.remoteDataChannel = nil
        self.videoCapturer = nil
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState
    ) {
        debugPrint("peerConnection new signaling state: \(stateChanged)")
        if stateChanged == .stable {
            self.hasExchangedSDP = true
            self.signalingDelegate?.webRTCClient(self, didChangeSignalingState: stateChanged)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint(
            "peerConnection did add stream with \(stream.videoTracks.count) video tracks and \(stream.audioTracks.count) audio tracks"
        )
        if let videoTrack = stream.videoTracks.first {
            self.remoteVideoTrack = videoTrack
            debugPrint("Remote video track received and set: \(videoTrack)")
            debugPrint("Remote video track enabled: \(videoTrack.isEnabled)")
            debugPrint("Remote video track readyState: \(videoTrack.readyState)")

            // Add the track to the renderer if we have one
            if let renderer = self.remoteVideoRenderer {
                debugPrint("Adding remote video track to existing renderer")
                videoTrack.add(renderer)
                debugPrint("Remote track added to existing renderer")
            }
        } else {
            debugPrint("No video track found in received stream")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("peerConnection did remove stream")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("peerConnection should negotiate")
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState
    ) {
        debugPrint("peerConnection new connection state: \(newState)")
        if newState == .checking {
            debugPrint(
                "ICE connection checking - gathering state: \(peerConnection.iceGatheringState)")
        }
        self.delegate?.webRTCClient(self, didChangeConnectionState: newState)
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState
    ) {
        debugPrint("peerConnection new gathering state: \(newState)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate)
    {
        debugPrint("peerConnection did generate candidate: \(candidate)")
        self.signalingDelegate?.webRTCClient(self, didGenerate: candidate)
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]
    ) {
        debugPrint("peerConnection did remove candidate(s)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("peerConnection did open data channel")
        self.remoteDataChannel = dataChannel
    }
}

extension WebRTCClient {
    private func setTrackEnabled<T: RTCMediaStreamTrack>(_ type: T.Type, isEnabled: Bool) {
        peerConnection.transceivers
            .compactMap { return $0.sender.track as? T }
            .forEach { $0.isEnabled = isEnabled }
    }
}

extension WebRTCClient: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        debugPrint("dataChannel did change state: \(dataChannel.readyState)")
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        self.delegate?.webRTCClient(self, didReceiveData: buffer.data)
    }
}

// MARK:- Audio control
extension WebRTCClient {
    func muteAudio() {
        self.setAudioEnabled(false)
    }

    func unmuteAudio() {
        self.setAudioEnabled(true)
    }

    // Fallback to the default playing device: headphones/bluetooth/ear speaker
    func speakerOff() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord)
                try self.rtcAudioSession.overrideOutputAudioPort(.none)
            } catch let error {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }

    // Force speaker
    func speakerOn() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord)
                try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
                try self.rtcAudioSession.setActive(true)
            } catch let error {
                debugPrint("Couldn't force audio to speaker: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }

    private func setAudioEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCAudioTrack.self, isEnabled: isEnabled)
    }
}
