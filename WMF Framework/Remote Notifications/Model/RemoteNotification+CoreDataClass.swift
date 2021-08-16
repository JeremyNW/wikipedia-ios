import Foundation
import CoreData

@objc public enum RemoteNotificationCategory: Int {
    case editReverted
    case unknown

    init(stringValue: String) {
        switch stringValue {
        case "reverted":
            self = .editReverted
        default:
            self = .unknown
        }
    }
}

@objc(RemoteNotification)
public class RemoteNotification: NSManagedObject {

    public var category: RemoteNotificationCategory {
        guard let categoryString = categoryString else {
            return .unknown
        }
        return RemoteNotificationCategory(stringValue: categoryString)
    }
}
