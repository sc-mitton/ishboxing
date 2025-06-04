import SwiftUI

struct OTPVerificationView: View {
    let phoneNumber: String
    @StateObject private var supabaseService = SupabaseService()
    @State private var otp = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var navigateToUsername = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter verification code")
                .font(.bangers(size: 28))
                .foregroundColor(.ishRed)
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
                        .font(.bangers(size: 20))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(Color.ishRed)
                        .cornerRadius(8)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(otp.count != 6 || isLoading)

            Spacer()
        }
        .padding()
        .background(Color.ishBlue.opacity(0.1))
        .navigationDestination(isPresented: $navigateToUsername) {
            UsernameSetupView()
        }
    }

    private func verifyOTP() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabaseService.verifyOTP(phoneNumber: phoneNumber, token: otp)
            navigateToUsername = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
