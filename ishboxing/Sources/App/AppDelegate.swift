import Foundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    let supabase = SupabaseService.shared

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        Task {
            do {
                try await supabase.saveAPNToken(
                    token: token,
                    deviceId: deviceId
                )
            } catch {
                print("❌ Failed to save APN token: \(error)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}
