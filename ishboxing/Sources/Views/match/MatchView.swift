import Foundation
import Supabase
import SwiftUI
import WebRTC

struct MatchView: View {
    let friend: User
    let match: Match?
    let supabaseService = SupabaseService.shared
    let webRTCClient: WebRTCClient

    @StateObject private var viewModel: MatchViewModel

    init(friend: User, match: Match?) {
        self.match = match
        self.friend = friend

        self.webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers)
        let signalClient = SignalClient(supabase: supabaseService, webRTCClient: webRTCClient)

        self._viewModel = StateObject(
            wrappedValue: MatchViewModel(
                signalClient: signalClient,
                friend: friend,
                match: match
            ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
            }
            .padding()
            .navigationTitle("Fight")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
