import Foundation
import UserNotifications

class NotificationHandler: NSObject {
    static let shared = NotificationHandler()

    private override init() {
        super.init()
    }

    func handleMatchNotification(_ userInfo: [AnyHashable: Any]) {
        guard let fromData = userInfo["from"] as? [String: Any],
            let toData = userInfo["to"] as? [String: Any],
            let id = userInfo["id"] as? String
        else {
            print("❌ Missing required notification data")
            return
        }

        let match = MatchNotificationPayload(
            id: id,
            from: .init(id: fromData["id"] as! String, username: fromData["username"] as! String),
            to: .init(id: toData["id"] as! String, username: toData["username"] as! String)
        ).toMatch()

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .init("MatchNotificationReceived"),
                object: nil,
                userInfo: ["match": match]
            )
        }
    }
}
