import SwiftUI

class UserManagement: ObservableObject {
    @Published var phoneNumber: String?
    @Published var isInMatch = false
}
