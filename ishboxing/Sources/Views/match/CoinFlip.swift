import SwiftUI

struct CoinFlip: View {
    @State private var isFlipping = false
    @State private var isHeads = false
    @State private var rotation: Double = 0

    let onResult: (Bool) -> Void

    var body: some View {
        VStack {
            Circle()
                .fill(isHeads ? Color.yellow : Color.gray)
                .frame(width: 100, height: 100)
                .overlay(
                    Text(isHeads ? "H" : "T")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                )
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipping ? 1 : 0.8)
        }
        .onTapGesture {
            flipCoin()
        }
    }

    private func flipCoin() {
        guard !isFlipping else { return }

        isFlipping = true
        let randomResult = Bool.random()

        withAnimation(.easeInOut(duration: 0.5)) {
            rotation += 360
            isHeads = randomResult
        }

        // Add a slight delay before calling the callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isFlipping = false
            onResult(randomResult)
        }
    }
}

#Preview {
    CoinFlip { result in
        print("Coin landed on: \(result ? "Heads" : "Tails")")
    }
}
