import SwiftUI

struct GestureOverlay: View {
    let isEnabled: Bool
    let onSwipe: (CGPoint?) -> Void

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onSwipe(value.location)
                    }
                    .onEnded { value in
                        onSwipe(value.location)
                        onSwipe(nil)
                    }
            )
            .disabled(!isEnabled)
    }
}
