import Foundation
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let supabase = SupabaseService.shared
    let friendManagement = FriendManagement.shared
    let notificationHandler = NotificationHandler.shared

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

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
        print("Notification received: \(response.notification.request.content)")
        handleNotification(response.notification.request.content)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) ->
            Void
    ) {
        handleNotification(notification.request.content)
        completionHandler(.sound)
    }

    private func handleNotification(_ content: UNNotificationContent) {
        let catIdentifier = content.categoryIdentifier

        if catIdentifier == "FRIEND_REQUEST" || catIdentifier == "FRIEND_CONFIRMATION" {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            Task { @MainActor in
                await friendManagement.fetchFriends()
            }
        } else if catIdentifier == "MATCH_NOTIFICATION" {
            notificationHandler.handleMatchNotification(content.userInfo)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}
