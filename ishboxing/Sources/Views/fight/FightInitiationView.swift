import Foundation
import Supabase
import SwiftUI
import WebRTC

struct FightInitiationView: View {
    let friend: User
    let meeting: Meeting?
    let supabaseService = SupabaseService.shared
    let webRTCClient: WebRTCClient

    @StateObject private var viewModel: FightInitiationViewModel

    init(friend: User, meeting: Meeting?) {
        self.meeting = meeting
        self.friend = friend

        self.webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers)
        let signalClient = SignalClient(supabase: supabaseService, webRTCClient: webRTCClient)

        self._viewModel = StateObject(
            wrappedValue: FightInitiationViewModel(
                signalClient: signalClient,
                friend: friend,
                meeting: meeting
            ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
            }
            .padding()
            .navigationTitle("Fight Initiation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
