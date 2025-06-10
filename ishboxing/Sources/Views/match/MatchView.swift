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

    init(friend: User, match: Match?) {
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
                match: match
            ))
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .padding()

                Spacer()
            }

            Text("Match")
                .font(.bangers(size: 28))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            Text("Match")
                .font(.bangers(size: 28))
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
}
