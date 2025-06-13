import SwiftUI

struct CountdownOverlay: View {
    let countdown: Int
    let isActive: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            Text("\(countdown) ")
                .font(.bangers(size: 120))
                .foregroundColor(.white)
                .scaleEffect(isActive ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: countdown)
        }
    }
}
