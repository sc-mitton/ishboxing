import SwiftUI

struct OTPVerificationView: View {
    @StateObject private var supabaseService = SupabaseService()
    @State private var otp = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject private var userManagement: UserManagement
    @EnvironmentObject private var router: Router
    @FocusState private var isOTPFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                if geometry.size.height > 800 {  // iPad-like height
                    Spacer()
                }

                Text("Enter verification code ")
                    .font(.bangers(size: 28))
                    .foregroundColor(.ishRed)
                    .padding(.top, geometry.size.height > 800 ? 0 : 50)

                Text("We sent a code to \(userManagement.phoneNumber ?? "")")
                    .foregroundColor(.secondary)

                VStack(spacing: 20) {
                    TextField("6-digit code", text: $otp)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.custom)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .focused($isOTPFocused)

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
                            Text("Verify ")
                                .font(.bangers(size: 20))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.ishRed)
                                .cornerRadius(8)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(otp.count != 6 || isLoading)
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
            isOTPFocused = true
        }
    }

    private func verifyOTP() async {
        isLoading = true
        errorMessage = nil
        do {
            let e164PhoneNumber = "1" + userManagement.phoneNumber!.filter { $0.isNumber }
            try await supabaseService.verifyOTP(phoneNumber: e164PhoneNumber, token: otp)
            await MainActor.run {
                router.path.append("username")
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
