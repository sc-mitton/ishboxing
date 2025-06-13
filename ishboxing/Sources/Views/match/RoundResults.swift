import SwiftUI

struct RoundResults: View {
    let roundResults: [[Int?]]
    let currentRound: [Int]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        let isCompact = horizontalSizeClass == .compact

        Group {
            if isCompact {
                // Two rows for compact screens
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        ForEach(0..<6) { roundIndex in
                            RoundCircle(
                                roundIndex: roundIndex,
                                roundResults: roundResults,
                                currentRound: currentRound
                            )
                        }
                    }

                    HStack(spacing: 12) {
                        ForEach(6..<12) { roundIndex in
                            RoundCircle(
                                roundIndex: roundIndex,
                                roundResults: roundResults,
                                currentRound: currentRound
                            )
                        }
                    }
                }
            } else {
                // Single row for regular screens
                HStack(spacing: 12) {
                    ForEach(0..<12) { roundIndex in
                        RoundCircle(
                            roundIndex: roundIndex,
                            roundResults: roundResults,
                            currentRound: currentRound
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(20)
    }
}

struct RoundCircle: View {
    let roundIndex: Int
    let roundResults: [[Int?]]
    let currentRound: [Int]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 24, height: 24)

            if roundIndex < currentRound[0] {
                if let result = roundResults[roundIndex][currentRound[1]] {
                    if result > 0 {
                        // Win - show star
                        Text("⭐️")
                            .font(.system(size: 16))
                    } else {
                        // Loss - show X
                        Text("X")
                            .font(.bangers(size: 16))
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

#Preview {
    RoundResults(
        roundResults: Array(repeating: [nil, nil], count: 12),
        currentRound: [0, 0]
    )
}
