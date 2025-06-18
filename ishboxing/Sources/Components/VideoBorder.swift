import SwiftUI

struct VideoBorder: ViewModifier {
    let color: Color
    let isActive: Bool
    let borderWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(color, lineWidth: borderWidth)
                    .blur(radius: isActive ? borderWidth * 0.5 : 0)
                    .opacity(isActive ? 0.8 : 0)
                    .animation(
                        .easeInOut(duration: isActive ? 0.3 : 0.7),
                        value: isActive
                    )
            )
    }
}

struct VideoBorderView: View {
    let borderSize: CGFloat
    let punchConnected: Bool
    let punchDodged: Bool

    @State private var connectedFlash = false
    @State private var dodgedFlash = false

    var body: some View {
        Color.clear
            .modifier(
                VideoBorder(
                    color: .red,
                    isActive: connectedFlash,
                    borderWidth: borderSize
                )
            )
            .modifier(
                VideoBorder(
                    color: .green,
                    isActive: dodgedFlash,
                    borderWidth: borderSize
                )
            )
            .onChange(of: punchConnected) { oldValue, newValue in
                if newValue {
                    withAnimation {
                        connectedFlash = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation {
                            connectedFlash = false
                        }
                    }
                }
            }
            .onChange(of: punchDodged) { oldValue, newValue in
                if newValue {
                    withAnimation {
                        dodgedFlash = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation {
                            dodgedFlash = false
                        }
                    }
                }
            }
    }
}
