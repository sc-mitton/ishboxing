import Foundation
import Supabase
import SwiftUI
import WebRTC

struct FightView: View {
    let friend: User
    let fight: Fight?
    let supabaseService = SupabaseService.shared
    let webRTCClient: WebRTCClient

    @StateObject private var viewModel: FightViewModel

    init(friend: User, fight: Fight?) {
        self.fight = fight
        self.friend = friend

        self.webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers)
        let signalClient = SignalClient(supabase: supabaseService, webRTCClient: webRTCClient)

        self._viewModel = StateObject(
            wrappedValue: FightViewModel(
                signalClient: signalClient,
                friend: friend,
                fight: fight
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
