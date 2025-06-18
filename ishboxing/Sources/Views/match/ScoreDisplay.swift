import SwiftUI

struct ScoreDisplay: View {
    let currentUsername: String
    let opposingUsername: String
    let currentUserDodges: Int
    let opposingUserDodges: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(currentUsername): \(currentUserDodges) ")
                .font(.bangers(size: 24))
                .foregroundColor(.white)
            Text("\(opposingUsername): \(opposingUserDodges) ")
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
        currentUserDodges: 2,
        opposingUserDodges: 1
    )
}
