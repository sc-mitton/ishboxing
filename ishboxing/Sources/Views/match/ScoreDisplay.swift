import SwiftUI

struct ScoreDisplay: View {
    let currentUsername: String
    let opposingUsername: String
    let currentUserDodges: Int
    let opposingUserDodges: Int
    let currentRound: [Int]  // [round, user possession]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(currentUsername): \(currentUserDodges) ")
                .font(.bangers(size: 24))
                .foregroundColor(.white)
            Text("\(opposingUsername): \(opposingUserDodges) ")
                .font(.bangers(size: 24))
                .foregroundColor(.white)
            Text("Round \(currentRound[0] + 1) ")
                .font(.bangers(size: 16))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
    }
}

#Preview {
    ScoreDisplay(
        currentUsername: "Player 1",
        opposingUsername: "Player 2",
        currentUserDodges: 2,
        opposingUserDodges: 1,
        currentRound: [0, 0]
    )
}
