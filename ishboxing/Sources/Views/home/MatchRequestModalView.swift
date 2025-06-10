import SwiftUI

struct MatchRequestModalView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var userManagement = UserManagement()
    let match: Match
    let onConfirm: () -> Void

    @State private var isPresented = false

    var body: some View {
        ZStack {
            // Overlay
            Color.black.opacity(0.7)
                .frame(
                    width: UIScreen.main.bounds.width * 3, height: UIScreen.main.bounds.height * 3
                )
                .ignoresSafeArea()
                .onTapGesture {
                    dismissModal()
                }
                .transition(.opacity)
                .opacity(isPresented ? 1 : 0)

            // Modal content
            VStack(spacing: 20) {
                Text("Match Request!")
                    .font(.bangers(size: 28))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)

                Text("\(match.from.username) has started a match!")
                    .font(.title3)
                    .foregroundColor(.white)

                HStack(spacing: 20) {
                    Button(action: {
                        dismissModal()
                    }) {
                        Text("Decline ")
                            .font(.bangers(size: 20))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .frame(height: 44)

                    Button(action: {
                        onConfirm()
                        dismissModal()
                    }) {
                        Text("Accept ")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = true
            }
        }
        .onDisappear {
            isPresented = false
        }
    }

    private func dismissModal() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
        dismiss()
    }
}
