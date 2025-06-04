import SwiftUI
import WebRTC

struct UsernameSetupView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMainView = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose a User Name")
                .font(.bangers(size: 28))
                .foregroundColor(.ishRed)
                .padding(.top, 50)

            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .autocapitalization(.none)
                .autocorrectionDisabled(true)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                Task {
                    await setUsername()
                }
            }) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Continue")
                        .font(.bangers(size: 20))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(Color.ishRed)
                        .cornerRadius(8)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(username.isEmpty || isLoading)

            Spacer()
        }
        .padding()
        .background(Color.ishBlue.opacity(0.1))
    }

    private func setUsername() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabaseService.updateUsername(username)
            showMainView = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func buildSignalingClient() -> SignalClient {
        let webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers)
        return SignalClient(supabase: supabaseService, webRTCClient: webRTCClient)
    }
}
