import SwiftUI

struct AddFriendModalView: View {
    @Environment(\.dismiss) var dismiss
    @State private var newFriendUsername: String = ""
    @State private var formError: String?
    @State private var isPresented: Bool = false
    @StateObject private var friendManagement: FriendManagement
    let onClose: () -> Void

    @FocusState private var isFocused: Bool

    init(friendManagement: FriendManagement, onClose: @escaping () -> Void) {
        _friendManagement = StateObject(wrappedValue: friendManagement)
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            // Overlay
            Color.black.opacity(0.7)
                .frame(
                    width: UIScreen.main.bounds.width * 3, height: UIScreen.main.bounds.height * 3
                )
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                    onClose()
                }
                .transition(.opacity)
                .opacity(isPresented ? 1 : 0)

            // Modal content
            VStack(spacing: 20) {
                Text("Add Friend ")
                    .font(.bangers(size: 28))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)

                TextField("Username", text: $newFriendUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isFocused)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                if let formError = formError {
                    Text(formError)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                        onClose()
                    }) {
                        Text("Cancel")
                            .font(.bangers(size: 20))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .frame(height: 44)

                    Button(action: {
                        Task {
                            await addFriend()
                        }
                    }) {
                        Text("Add ")
                            .font(.bangers(size: 20))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .background(Color.ishRed)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(height: 44)
                }
            }
            .padding()
            .background(Color.ishBlue)
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .frame(maxWidth: 400)
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(isPresented ? 1 : 0.95)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Ensure ZStack fills screen
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isFocused = true
            }
        }
        .ignoresSafeArea()
        .onAppear { isPresented = true }
        .onDisappear { isPresented = false }
    }

    private func addFriend() async {
        formError = nil
        do {
            try await friendManagement.addFriend(newFriendUsername)
            newFriendUsername = ""
        } catch {
            formError = error.localizedDescription
        }
    }
}
