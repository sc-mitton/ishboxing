import SwiftUI

struct GameOverModal: View {
    let currentUserStreak: Int
    let opposingUserStreak: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.bangers(size: 48))
                    .foregroundColor(.white)

                Text(winnerText)
                    .font(.bangers(size: 36))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text("END MATCH")
                        .font(.bangers(size: 24))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.ishRed)
                        .cornerRadius(24)
                }
            }
            .padding(32)
            .background(Color.black.opacity(0.9))
            .cornerRadius(24)
            .padding(32)
        }
    }

    private var winnerText: String {
        if currentUserStreak > opposingUserStreak {
            return "YOU WIN!"
        } else {
            return "YOU LOST"
        }
    }
}
