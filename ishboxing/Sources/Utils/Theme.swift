import SwiftUI

extension Color {
    static let ishBlue = Color(red: 0.13, green: 0.32, blue: 0.67)  // Splash background blue
    static let ishRed = Color(red: 0.91, green: 0.13, blue: 0.13)  // Boxing glove red
    static let ishLightBlue = Color(red: 0.25, green: 0.45, blue: 0.85)  // Starburst light blue
    static let ishDarkBlue = Color(red: 0.07, green: 0.18, blue: 0.36)  // Darker blue for gradients
}

extension Font {
    static func bangers(size: CGFloat) -> Font {
        .custom("Bangers-Regular", size: size)
    }
}

extension Text {
    static func mainTitle() -> CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 54 : 38
    }
}
