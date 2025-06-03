import SwiftUI

struct PhoneSignInView: View {
    @State private var supabaseService: SupabaseService
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showOTPView = false

    init() {
        self.supabaseService = SupabaseService.shared
    }

    var formattedPhoneNumber: String {
        let cleaned = phoneNumber.filter { $0.isNumber }
        guard cleaned.count > 0 else { return "" }

        var result = "("
        for (index, char) in cleaned.prefix(10).enumerated() {
            if index == 3 {
                result += ") "
            } else if index == 6 {
                result += "-"
            }
            result.append(char)
        }
        return result
    }

    var e164PhoneNumber: String {
        let numbers = phoneNumber.filter { $0.isNumber }
        return "+1" + numbers
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter your phone number")
                .font(.title)
                .padding(.top, 50)

            TextField("(555) 555-5555", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onReceive(phoneNumber.publisher) { newValue in
                    let filtered = String(newValue).filter { $0.isNumber }
                    if filtered.count <= 10 {
                        phoneNumber = formattedPhoneNumber
                    }
                }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                Task {
                    await signIn()
                }
            }) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(phoneNumber.filter { $0.isNumber }.count != 10 || isLoading)

            Spacer()
        }
        .padding()
        .navigationDestination(isPresented: $showOTPView) {
            OTPVerificationView(phoneNumber: e164PhoneNumber)
        }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabaseService.signInWithPhoneNumber(e164PhoneNumber)
            showOTPView = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
