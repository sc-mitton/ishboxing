import SwiftUI

struct ScoreDisplay: View {
    let currentUsername: String
    let opposingUsername: String
    let currentUserStreak: Int
    let opposingUserStreak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(currentUsername): \(currentUserStreak) ")
                .font(.bangers(size: 24))
                .foregroundColor(.white)
            Text("\(opposingUsername): \(opposingUserStreak) ")
                .font(.bangers(size: 24))
                .foregroundColor(.white)
        }
        .padding()
    }
}

#Preview {
    ScoreDisplay(
        currentUsername: "Player 1",
        opposingUsername: "Player 2",
        currentUserStreak: 3,
        opposingUserStreak: 1
    )
}
