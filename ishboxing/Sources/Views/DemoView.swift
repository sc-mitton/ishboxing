import SwiftUI

struct DemoView: View {
    @State private var showFightInitiation: Bool = false

    var friend = User(id: UUID(), username: "John Doe")

    var body: some View {
        VStack {
            Button(action: {
                showFightInitiation = true
            }) {
                Text("Connect to Friend")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showFightInitiation) {
            FightInitiationView(friend: friend, meeting: nil)
        }
    }
}

#Preview {
    DemoView()
}
