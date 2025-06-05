import SwiftUI

struct PhoneSignInView: View {
    @State private var supabaseService: SupabaseService
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Binding var navigationPath: NavigationPath
    @FocusState private var isPhoneNumberFocused: Bool

    init(navigationPath: Binding<NavigationPath>) {
        self.supabaseService = SupabaseService.shared
        self._navigationPath = navigationPath
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
        GeometryReader { geometry in
            VStack(spacing: 20) {
                if geometry.size.height > 800 {  // iPad-like height
                    Spacer()
                }

                Text("Enter your phone number")
                    .font(.bangers(size: 28))
                    .foregroundColor(.ishRed)
                    .padding(.top, geometry.size.height > 800 ? 0 : 50)

                VStack(spacing: 20) {
                    TextField("(555) 555-5555", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.custom)
                        .padding(.vertical, 12)
                        .focused($isPhoneNumberFocused)
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
                                .font(.bangers(size: 20))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.ishRed)
                                .cornerRadius(8)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(phoneNumber.filter { $0.isNumber }.count != 10 || isLoading)
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
            isPhoneNumberFocused = true
        }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabaseService.signInWithPhoneNumber(e164PhoneNumber)
            await MainActor.run {
                navigationPath.append(OTPRoute(phoneNumber: phoneNumber))
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
