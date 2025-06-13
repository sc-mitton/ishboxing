import SwiftUI

struct DisconnectedOverlay: View {
    let friendUsername: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("\(friendUsername) has left the match")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Button(action: onDismiss) {
                Text("End Match ")
                    .font(.bangers(size: 24))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.ishBlue)
                    .cornerRadius(25)
            }
        }
        .padding(30)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
    }
}
