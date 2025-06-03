import SwiftUI

struct OTPVerificationView: View {
    let phoneNumber: String
    @StateObject private var supabaseService = SupabaseService()
    @State private var otp = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showUsernameView = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter verification code")
                .font(.title)
                .padding(.top, 50)

            Text("We sent a code to \(phoneNumber)")
                .foregroundColor(.secondary)

            TextField("6-digit code", text: $otp)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                Task {
                    await verifyOTP()
                }
            }) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Verify")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(otp.count != 6 || isLoading)

            Spacer()
        }
        .padding()
        .navigationDestination(isPresented: $showUsernameView) {
            UsernameSetupView()
        }
    }

    private func verifyOTP() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabaseService.verifyOTP(phoneNumber: phoneNumber, token: otp)
            showUsernameView = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
