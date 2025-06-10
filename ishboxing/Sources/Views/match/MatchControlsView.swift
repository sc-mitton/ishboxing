import SwiftUI

struct MatchControlsView: View {
    @ObservedObject var viewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: MatchViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            HStack {
                // Close button
                Button(action: {
                    print("Closing match")
                    Task {
                        self.viewModel.endMatch()
                        print("Dismissing view")
                        dismiss()
                        
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 44, height: 44)
                        )
                }
                
                .padding(.leading, 20)
                .padding(.top, 20)

                Spacer()

                // Mute button
                Button(action: {
                    if self.viewModel.isMuted {
                        self.viewModel.unmuteAudio()
                    } else {
                        self.viewModel.muteAudio()
                    }
                }) {
                    Image(systemName: self.viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 44, height: 44)
                        )
                }
                .padding(.trailing, 20)
                .padding(.top, 20)
            }

            Spacer()

            if viewModel.showTimeoutAlert {
                // Centered close button with message
                VStack(spacing: 16) {
                    Text("User is unreachable")
                        .font(.headline)
                        .foregroundColor(.white)
                        .opacity(0.7)
                    Button(action: {
                        Task {
                            self.viewModel.endMatch()
                            dismiss()
                        }
                    }) {
                        Text("Dismiss ")
                            .font(.custom("Bangers", size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .cornerRadius(8)
                    }
                    .background(Color.ishRed)
                    .cornerRadius(16)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.7))
                )
            }

            Spacer()
        }
    }
}
