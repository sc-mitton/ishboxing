import SwiftUI

struct RoundResults: View {
    let roundResults: [[Int?]]
    let currentRound: Int
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isExpanded = true

    var currentUserStreak: Int {
        var streak = 0
        for i in (0..<currentRound).reversed() {
            if let result = roundResults[i][1], result > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    var opposingUserStreak: Int {
        var streak = 0
        for i in (0..<currentRound).reversed() {
            if let result = roundResults[i][0], result > 0 {
                streak += 1
            } else {
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
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
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
                if let result = roundResults[roundIndex][1] {
                    if result > 0 {
                        // Win - show star
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 28, height: 28)
                            Text("⭐️")
                                .font(.system(size: 16))
                        }
                    } else {
                        // Loss - show X
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.3))
                                .frame(width: 28, height: 28)
                            Text("🪦")
                                .font(.bangers(size: 16))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    RoundResults(
        roundResults: Array(repeating: [nil, nil], count: 12),
        currentRound: 0
    )
}
