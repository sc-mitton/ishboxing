import SwiftUI

struct RoundResults: View {
    let roundResults: [[Int?]]
    let currentRound: [Int]  // [round, user possession]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isExpanded = true

    var currentUserStreak: Int {
        var streak = 0
        for i in (0..<currentRound[0]).reversed() {
            let currentUserDodges = roundResults[i][0] ?? 0
            let opponentDodges = roundResults[i][1] ?? 0

            if currentUserDodges > opponentDodges {
                // Win - current user has more dodges
                streak += 1
            } else {
                // Break streak on loss or draw
                break
            }
        }
        return streak
    }

    var opposingUserStreak: Int {
        var streak = 0
        for i in (0..<currentRound[0]).reversed() {
            let currentUserDodges = roundResults[i][0] ?? 0
            let opponentDodges = roundResults[i][1] ?? 0

            if opponentDodges > currentUserDodges {
                // Win - opponent has more dodges
                streak += 1
            } else {
                // Break streak on loss or draw
                break
            }
        }
        return streak
    }

    var body: some View {
        let isCompact = horizontalSizeClass == .compact

        HStack(spacing: 24) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                Text("🏆")
                    .font(.system(size: 24))
            }

            if isExpanded {
                Group {
                    if isCompact && roundResults.count > 5 {
                        // Two rows for compact screens only when there are more than 5 rounds
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                ForEach(0..<roundResults.count / 2) { roundIndex in
                                    RoundCircle(
                                        roundIndex: roundIndex,
                                        roundResults: roundResults,
                                        currentRound: currentRound[0]
                                    )
                                }
                            }

                            HStack(spacing: 12) {
                                ForEach(roundResults.count / 2..<roundResults.count) { roundIndex in
                                    RoundCircle(
                                        roundIndex: roundIndex,
                                        roundResults: roundResults,
                                        currentRound: currentRound[0]
                                    )
                                }
                            }
                        }
                    } else {
                        // Single row for regular screens or when 5 or fewer rounds
                        HStack(spacing: 12) {
                            ForEach(0..<roundResults.count) { roundIndex in
                                RoundCircle(
                                    roundIndex: roundIndex,
                                    roundResults: roundResults,
                                    currentRound: currentRound[0]
                                )
                            }
                        }
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .onAppear {
            // Auto-close after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }
    }
}

struct RoundCircle: View {
    let roundIndex: Int
    let roundResults: [[Int?]]
    let currentRound: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 28, height: 28)

            if roundIndex < currentRound {
                let currentUserDodges = roundResults[roundIndex][0] ?? 0
                let opponentDodges = roundResults[roundIndex][1] ?? 0

                if currentUserDodges > opponentDodges {
                    // Win - current user has more dodges
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 28, height: 28)
                        Text("⭐️")
                            .font(.system(size: 16))
                    }
                } else if opponentDodges > currentUserDodges {
                    // Loss - opponent has more dodges
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 28, height: 28)
                        Text("🪦")
                            .font(.bangers(size: 16))
                    }
                } else {
                    // Draw - same number of dodges
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: 28, height: 28)
                        Text("🤝")
                            .font(.system(size: 16))
                    }
                }
            }
        }
    }
}

#Preview {
    RoundResults(
        roundResults: Array(repeating: [nil, nil], count: 5),
        currentRound: [0, 0],
    )
}
