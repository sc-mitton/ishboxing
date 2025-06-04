import SwiftUI

struct AddFriendModal: View {
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
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                    onClose()
                }

            // Modal content
            VStack(spacing: 20) {
                Text("Add Friend")
                    .font(.title2)
                    .bold()

                TextField("Username", text: $newFriendUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .frame(height: 44)

                    Button(action: {
                        Task {
                            await addFriend()
                        }
                    }) {
                        Text("Add")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(height: 44)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(.horizontal, 40)
            .frame(maxWidth: 400)  // Limit maximum width for larger screens
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Ensure ZStack fills screen
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isFocused = true
            }
        }
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
