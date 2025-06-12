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
                    Task {
                        self.viewModel.endMatch()
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.ishRed)
                                .frame(width: 44, height: 44)
                        )
                }
                .padding(.leading, 20)
                .padding(.top, 20)

                // Mute button
                Button(action: {
                    if self.viewModel.isMuted {
                        self.viewModel.unmuteAudio()
                    } else {
                        self.viewModel.muteAudio()
                    }
                }) {
                    Image(systemName: self.viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.ishRed)
                                .frame(width: 44, height: 44)
                        )
                }
                .padding(.leading, 20)
                .padding(.top, 20)

                Spacer()
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
