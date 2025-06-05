import SwiftUI
import WebRTC

struct UsernameSetupView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Binding var navigationPath: NavigationPath
    @FocusState private var isUsernameFocused: Bool

    init(navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                if geometry.size.height > 800 {  // iPad-like height
                    Spacer()
                }

                Text("Choose a User Name ")
                    .font(.bangers(size: 28))
                    .foregroundColor(.ishRed)
                    .padding(.top, geometry.size.height > 800 ? 0 : 50)

                VStack(spacing: 20) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.custom)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .focused($isUsernameFocused)

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
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.ishRed)
                                .cornerRadius(8)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(username.isEmpty || isLoading)
                }
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity)

                if geometry.size.height > 800 {  // iPad-like height
                    Spacer()
                } else {
                    Spacer()
                }
            }
            .padding()
            .background(Color.ishBlue.opacity(0.1))
        }
        .onAppear {
            isUsernameFocused = true
        }
    }

    private func setUsername() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabaseService.updateUsername(username)
            await MainActor.run {
                supabaseService.isAuthenticated = true
                navigationPath.removeLast(navigationPath.count)
            }
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
