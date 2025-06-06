import SwiftUI

class Router: ObservableObject {
    @Published var path = NavigationPath()
    @Published var phoneNumber: String?
}
