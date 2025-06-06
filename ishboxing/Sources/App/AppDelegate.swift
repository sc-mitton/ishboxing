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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.categoryIdentifier == "FRIEND_REQUEST" {
            let friendId = response.notification.request.content.userInfo["to"] as? String
            if let friendId = friendId {
                Task {
                    do {
                        try await supabase.confirmFriendship(friendId)
                        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                    } catch {
                        print("❌ Failed to confirm friendship: \(error)")
                    }
                }
            }
        } else if response.notification.request.content.categoryIdentifier == "FIGHT_NOTIFICATION" {
            handleFightNotification(response.notification.request.content.userInfo)
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) ->
            Void
    ) {
        if notification.request.content.categoryIdentifier == "FIGHT_NOTIFICATION" {
            handleFightNotification(notification.request.content.userInfo)
        }
        completionHandler(.sound)
    }

    private func handleFightNotification(_ userInfo: [AnyHashable: Any]) {
        if let fightData = userInfo["meeting"] as? [String: String],
            let from = fightData["from"],
            let to = fightData["to"],
            let id = fightData["id"]
        {
            let fight = Fight(from: from, to: to, id: id)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FightNotificationReceived"),
                    object: nil,
                    userInfo: ["fight": fight]
                )
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
